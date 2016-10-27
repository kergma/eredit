package eredit::Model::er;
use Moose;
use namespace::autoclean;
use utf8;

extends 'Catalyst::Model';

use DBI;
use Digest::MD5;
use Encode;
use Date::Format;

no warnings qw/uninitialized experimental/;

=head1 NAME

wf::Model::udb - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Pushkinsv

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;


my $isuid='3019f26b-c6d5-41bb-9d1e-7311b675f46f'; # UDB
my $cc;

sub ACCEPT_CONTEXT
{
	my ($self,$c,@args)=@_;

	$cc=$c;
	return $self;
}

sub arrayref;
sub arrayref($)
{
	my ($v)=@_;
	return $v if ref $v eq 'ARRAY';
	return [$v];
}

sub timestame_of_id
{
	my ($self,$id,$format)=@_;
	$format//='%Y-%m-%d %H:%M:%S';
	my $t=str2time(db::selectval_scalar('select timestame_of_id(?)',undef,$id));
	return time2str($t,$format);
}

sub entities
{
	my ($self, $f)=@_;
	return read_table($self,qq/select * from er.entities(?,?,?,?,?)/,$f->{en},$f->{name},$f->{type},$f->{domain},$f->{limit});
}

sub record_of
{
	my ($self,$id,$domain)=@_;
	return db::selectall_arrayref(qq/select * from er.record_of(?,?) order by value is null, key, name2, name1/,{Slice=>{}},$id,$domain);
}

sub types
{
	my ($self)=@_;
	return cached_array_ref($self,q/select distinct type from er.typing where domain=coalesce(null,domain) order by 1/);
}
sub domains
{
	my ($self)=@_;
	return cached_array_ref($self,q/select distinct domain from er.keys order by 1/);
}

sub row
{
	my ($self,$table, $row)=@_;
	return db::selectall_arrayref(qq\
select (r).*, (e).*, (k).* from (
select r,case when "column" like 'e%' and value is not null then (select er.entities(value::int8) as e) end as e,
case when "column" ='r' and value is not null then (select k from er.keys k where id=value::int8) end as k
from er.row(?,?) as r
) s
\,{Slice=>{}},$table,$row);
}

sub row_update
{
	my ($self, $old, $new)=@_;
	my $table=(grep {$_->{column} eq 'table'} @$old)[0]->{value};
	my $row=(grep {$_->{column} eq 'row'} @$old)[0]->{value};
	delete $new->{row};
	undef $_ foreach grep {!$_} values %$new;

	return db::selectall_arrayref(qq/select * from er.chrow(?,?,?,?)/,{Slice=>{}},$table,$row,[keys %$new],[values %$new]);
}

sub storages
{
	my ($self,$domain)=@_;
	return db::selectall_arrayref(qq/select * from er.storages order by ?=any(domains) desc,"table"/,{Slice=>{}},$domain);
}

sub entity
{
	my ($self,$en,$domain)=@_;
	return db::selectrow_hashref(qq/select * from er.entities(coalesce(?,0::int8),null,null,?)/,undef,$en,$domain);
}

sub array_ref
{
	my ($self, $q, @values)=@_;

	my $opts={row=>'auto'};
	if (ref $q eq 'HASH')
	{
		%$opts=(%$opts,%$q);
		$q=shift @values;
	};

	my $sth;
	if ($opts->{use_safe_connection})
	{
		my $sdbh=$self->sconnect() or return undef;
		$sth=$sdbh->prepare($q);
	}
	else
	{
		$sth=db::prepare($q);
	};
	my $r=$sth->execute(@values);
	return undef unless $r;
	my $row=$opts->{row};
	$opts->{row}='hashref' if ($opts->{row}//'auto') eq 'auto' and scalar(@{$sth->{NAME}})>1;
	$opts->{row}='col' if ($opts->{row}//'auto') eq 'auto' and scalar(@{$sth->{NAME}})==1;
	my @result=();
	while(my $r=($opts->{row} eq 'hashref'?$sth->fetchrow_hashref:$sth->fetchrow_arrayref))
	{
		push @result,$r->[0] if $opts->{row} eq 'col';
		push @result,$r if $opts->{row} eq 'hashref';
		push @result,[@$r] if $opts->{row} eq 'arrayref';
		push @result,[@$r] if $opts->{row} eq 'enhash';
	}
	if ($opts->{row} eq 'enhash')
	{
		my $r={};
		$r->{$_->[0]}=$_ foreach @result;
		return $r;
	};
	return \@result;
}

sub cached_array_ref
{
	my ($self, $q, @values)=@_;
	my $opts={};
	if (ref $q eq 'HASH')
	{
		$opts=$q;
		$q=shift @values;
	};

	my $md5=Digest::MD5->new;
	$md5->add($opts->{cache_key}) if defined $opts->{cache_key};
	use Encode qw(encode_utf8);
	$md5->add(encode_utf8($q));
	$md5->add(encode_utf8($_)) foreach @values;
	my $qkey=$md5->hexdigest();

	my $result=$cc->cache->get("aref-".$qkey);
	undef $result if $opts->{update};
	unless ($result)
	{
		$result=array_ref(@_);
		$cc->cache->set("aref-".$qkey,$result) if defined $result;
	};
	return $result;
}

sub read_table
{
	my $self=shift;
	my $query=shift;
	my @values=@_;

	my $start=time;

	my $sth=db::prepare($query);
	$sth->execute(@values);

	my %result=(query=>$query,values=>[@values],header=>[map(encode("utf8",$_),@{$sth->{NAME}})],rows=>[]);

	while(my $r=$sth->fetchrow_hashref)
	{
		push @{$result{rows}}, {map {encode("utf8",$_) => $r->{$_}} keys %$r};;
	};
	$sth->finish;

	$result{duration}=time-$start;
	$result{retrievedf}=$result{retrieved}=time2str('%Y-%m-%d %H:%M:%S',time);

	return \%result;
}

sub generate_id()
{
	my $self=shift;
	return db::selectval_scalar("select generate_id()");
}

sub keys()
{
	my ($self, $q)=@_;
	return cached_array_ref($self,{row=>'enhash'},"select * from er.keys");
}

1;
