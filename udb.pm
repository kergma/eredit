package wf::Model::udb;
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

sub mm
{
	my ($self)=@_;
	return [
		{t=>'Просмотр',i=>[{t=>'Записи',a=>'/rec/search'},{t=>'Записи ER',a=>'/rec/ersearch'},{t=>'Данные ИС',a=>'/sys/isdata'}]},
		{t=>'Создать',i=>[{t=>'Запись',a=>'/rec/create'},{t=>'Запись ER',a=>'/rec/ercreate'},{t=>'Ключ PKI',a=>'/pki/genpkey'},{t=>'Запрос сертификата PKI',a=>'/pki/crreq'},{t=>'Сертификат PKI',a=>'/pki/crcert'},{t=>'Импорт объекта PKI',a=>'/pki/import'}]},
		{t=>'Синхронизация',i=>[{t=>'Статус',a=>'/sync/status'},{t=>'Выполнить',a=>'/sync/perform'}]},
	];
}

sub arrayref;
sub arrayref($)
{
	my ($v)=@_;
	return $v if ref $v eq 'ARRAY';
	return [$v];
}

sub search_records
{
	my ($self,$filter)=@_;

	my %where=('1=?',1);
	$where{'recid=?'}=$filter->{recid} if $filter->{recid};
	$where{'lower(defvalue)~lower(?)'}=$filter->{defvalue} if $filter->{defvalue};
	$where{'lower(defvalue)~lower(?)'}=~s/ +/\.\*/ if $filter->{defvalue};
	$where{sprintf("rectype in (%s)",join(',', map {'?'} @{arrayref $filter->{rectype}}))}=arrayref $filter->{rectype} if $filter->{rectype};
	$where{"exists (select 1 from data where (v1=recid or v2=recid) and (v1=? or v2=?))"}=[$filter->{related},$filter->{related}] if $filter->{related};
	my $limit=$filter->{limit}||0;
	$limit+0 or $limit="";
	$limit and $limit="limit $limit";
	return read_table($self,sprintf(qq/select * from recv where %s order by 2 $limit/,join(" and ",keys %where)),map(@{arrayref $_}, grep {$_ ne 'novalue'} values %where));
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

sub tree_items
{
	my ($self, $en,$p)=(shift,shift,pop);
	undef $en if $en eq 'undefined';
	my $relations=[@_];
	my $names_selector=db::selectval_scalar('select er.names_selector()');
	my $types_filter='';
	$p->{types}=$p->{'types[]'} if $p->{'types[]'};
	$p->{types}=[$p->{types}] if ref $p->{types} ne 'ARRAY';
	$types_filter='join er.typing y on y.keyid=d.r and type=any(?)' if $p->{types};

	my $path=[];
	$path=db::selectall_arrayref(qq\
with s as (
select t.path[array_length(t.path,1)-1] as en, t.path[array_length(t.path,1)] as pa, array_length(t.path,1) as o,path from er.tree_from(?::int8,?::int8[],true) t order by t.path
),
z as (
select * from s where en is not null union
select pa,null,o+1,path from s s2 where not exists (select 1 from s where s.en=s2.pa)
)
select en,(array_agg_notnull(pa order by o))[1] as parent from z group by en order by array_agg(o order by o)
\,{Slice=>{}},$en,$relations) if $p->{descend};
	unshift @$path,{en=>'x',parent=>$en};
	my $r=[];
	foreach my $x (@$path)
	{
		my $i=cached_array_ref($self,qq\
select r.en,
($names_selector)[1] as name
@{[$x->{parent}?qq*from (select path[array_length(path,1)] as en, null from er.tree_from(?::int8,?::int8[],false,1,1) ) r*:qq*from er.roots(?::int8[]) r(en,names)*]}
join ( select * from subjects union select * from authorities ) d on r.en in (d.e1,d.e2)
$types_filter
left join er.naming n on n.keyid=d.r
group by r.en
order by 2
\,$x->{parent}||(),$relations,$p->{types}||());
		push @$r,{'en'=>$x->{en}, $x->{en} => $i};
	};
	return $r;
}

sub read_record
{
	my ($self,$id)=@_;
	return db::selectall_arrayref(qq/
select s.*,
(select comma(distinct defvalue) from recv where recid<>? and (recid=s.v1 or recid=s.v2)) as refdef,
(select comma(distinct rectype) from recv where recid<>? and (recid=s.v1 or recid=s.v2)) as reftype 
from
(select id,v1,r,null as v2 from data where v2=? union select id,null as v1,r,v2 from data where v1=?) s
order by r,refdef
/,{Slice=>{}},$id,$id,$id,$id);

}

sub record_of
{
	my ($self,$id,$domain)=@_;
	return db::selectall_arrayref(qq/select * from er.record_of(?,?) order by value is null, key, name2, name1/,{Slice=>{}},$id,$domain);
}
sub record_of_requested
{
	my ($self,$id,$domain)=@_;
	return db::selectall_arrayref(qq/
with i as (
	select ?::int8 as id
),
r as (
	select (r).* from (select er.record_of(id) as r from i) s
),
c as (
	select c.* from changes c join r on r.table=c.table and r.row=c.row where not exists (select 1 from changes where "table"=c.table and "row"=c.row and request>c.request)
	union
	select c.* from changes c,i where (('e1',null,id)::er.row=any(data) or ('e2',null,id)::er.row=any(data))
),
x as (
	select
	(select e from er.entities(coalesce((select (u).value::int8 from unnest((c).data) as u where (u).column='e1' and isid((u).value)),-1)) e) as e1,
	(select k from er.keys k where id=(select (u).value::int8 from unnest((c).data) as u where (u).column='r')) as r,
	(select e from er.entities(coalesce((select (u).value::int8 from unnest((c).data) as u where (u).column='e2' and isid((u).value)),-1)) e) as e2,
	(select (u).value from unnest((c).data) as u where (u).column='t') as value,
	c
	from c
),
cx as (
	select (c).*,
	(e1).en as e1, (e1).names[1] as name1,
	(r).id as r, (r).key, (r).domain,
	(e2).en as e2, (e2).names[1] as name2,
	value
	from x
)
select coalesce(r."table",cx."table") as "table", coalesce(r.row,cx.row) as row, r.e1, r.name1, r.r, r.key, r.domain, r.e2, r.name2, r.value,
(select nullif(array_agg_md(array[array[d.column,d.type, d.value]]),'{}') from unnest(data) d) as data,
action,request,requester,resolve,resolver,resolution,note,
coalesce(cx.e1::text,(select (u).value from unnest(data) as u where (u).column='e1')) as c_e1, cx.name1 as c_name, cx.r as c_r, cx.key as c_key, cx.domain as c_domain, coalesce(cx.e2::text,(select (u).value from unnest(data) as u where (u).column='e2')) as c_e2, cx.name2 as c_name2, cx.value as c_value
from r full join cx on cx.table=r.table and cx.row=r.row
order by r.value is null, r.key, r.row
/,{Slice=>{}},$id);
;
}
sub request_update
{
	my ($self,$a)=@_;
	my ($k,$r,$v)=($a->{key},$a->{rr},$a->{value});
	my $d;
	if ($k->[4])
	{
		$v=[$v] unless ref $v eq 'ARRAY';
		shift @$v while $v->[0] eq '<выбрать>';
		$v=shift @$v;
		$d=[['e1',undef,$cc->user->{entity}->{en}],['r',undef,$r->{r}],['e2',undef,$v]];
	}
	else
	{
		$d=['t',undef,$v];
	};
	db::do('delete from changes where "table"=? and "row"=? and request=?',undef,$r->{table},$r->{row},$r->{request});
	return db::selectall_arrayref(q/insert into changes ("table","row",action,request,requester,data) select ?::text,?::int,'update',coalesce(?::int8,generate_id()),?::int8,array_agg((e[1],e[2],e[3])::er.row) from unnest_md(?::text[][]) as e returning */,{Slice=>{}},$r->{table},$r->{row},undef,$cc->user->{entity}->{en},$d);
}
sub request_delete
{
	my ($self,$r)=@_;
	db::do('delete from changes where "table"=? and "row"=? and request=?',undef,$r->{table},$r->{row},$r->{request});
	return db::selectall_arrayref(q/insert into changes ("table","row",action,request,requester) select ?::text,?::int,'delete',coalesce(?::int8,generate_id()),?::int8 returning */,{Slice=>{}},$r->{table},$r->{row},undef,$cc->user->{entity}->{en});
}
sub request_insert
{
	my ($self,$a)=@_;
	my ($k,$v)=($a->{key},$a->{value});
	my $d;
	if ($k->[4])
	{
		$v=[$v] unless ref $v eq 'ARRAY';
		shift @$v while $v->[0] eq '<выбрать>';
		$v=shift @$v;
		$d=[['e1',undef,$cc->user->{entity}->{en}],['r',undef,$k->[0]],['e2',undef,$v]];
	}
	else
	{
		$d=[['e1',undef,$cc->user->{entity}->{en}],['r',undef,$k->[0]],['t',undef,$v]];
	};
	return db::selectall_arrayref(q/insert into changes ("table",action,request,requester,data) select ?::text,'insert',coalesce(?::int8,generate_id()),?::int8,array_agg((e[1],e[2],e[3])::er.row) from unnest_md(?::text[][]) as e returning */,{Slice=>{}},$k->[3],undef,$cc->user->{entity}->{en},$d);
}
sub cancel_request
{
	my ($self,$r)=@_;
	db::do('delete from changes where "table"=? and coalesce("row",0)=coalesce(?,0) and request=?',undef,$r->{table},$r->{row},$r->{request});
}
sub test
{
	my ($self,$id,$domain)=@_;
	return db::selectall_arrayref(qq/select data from changes/);
}

sub rectypes
{
	my ($self)=@_;
	return cached_array_ref($self,q/select distinct regexp_replace(rectype,'^.*PKI$','Объект PKI') from recv where rectype is not null order by 1/);
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
sub islist
{
	my ($self)=@_;
	return cached_array_ref($self,qq/select distinct v2 as isuid, v1 as isname from data where r='наименование ИС'/);
}
sub read_row
{
	my ($self,$id)=@_;
	return db::selectrow_hashref(qq/
select s.*,
(select comma(distinct defvalue) from recv where recid=s.v1) as def1,
(select comma(distinct rectype) from recv where recid=s.v1) as rt1,
(select comma(distinct defvalue) from recv where recid=s.v2) as def2,
(select comma(distinct rectype) from recv where recid=s.v2) as rt2
from data s where id=?
/,undef,$id);

}
sub read_isdata
{
	my ($self,$isuid)=@_;
	return undef unless $isuid;
	return read_table($self,qq\
select fio_so.v2 as souid,comma(distinct fio_so.v1) as fio,
ac_so.v1 as acuid,
(select v1 from data where v2=ac_so.v1 and r='имя входа учётной записи' limit 1) as login,
(select v1 from data where v2=ac_so.v1 and r='пароль ct учётной записи' limit 1) as passw,
(select comma(distinct v1) from data p join context_of(def_is.v2,fio_so.v2) c on c.item=p.v2 and p.r='свойства сотрудника') as props
from data def_is 
join data dcon on dcon.v2=def_is.v2 or (dcon.v2 in (select container from containers_of(def_is.v2) where level=1) and dcon.r like 'наименование%')
join data fio_so on fio_so.r='ФИО сотрудника' and (dcon.v2 in (select container from containers_of(fio_so.v2)) or exists (select 1 from data so join data ac on ac.v2=so.v1 and so.r='учётная запись сотрудника' where so.v2=fio_so.v2 and ac.v1=def_is.v2 and ac.r='информационная система учётной записи'))
join data ac_so on ac_so.r='учётная запись сотрудника' and ac_so.v2=fio_so.v2 and (not exists (select 1 from data where r='информационная система учётной записи' and v2=ac_so.v1) or exists (select 1 from data where r='информационная система учётной записи' and v2=ac_so.v1 and v1=def_is.v2))
where def_is.v2=? and def_is.r='наименование ИС'
group by fio_so.v2,ac_so.v1,def_is.v2
order by 2
\,$isuid);
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

sub datarow
{
	my ($self,$id)=@_;
	return undef unless $id;
	return db::selectrow_hashref(qq/select * from data where id=?/,undef,$id);
}

sub storages
{
	my ($self,$domain)=@_;
	return db::selectall_arrayref(qq/select * from er.storages order by ?=any(domains) desc,"table"/,{Slice=>{}},$domain);
}
sub recdef
{
	my ($self,$recid)=@_;
	my $r=db::selectrow_arrayref(qq/select defvalue,rectype from recv where recid=?/,undef,$recid);
	return (undef,undef) unless $r;
	return @$r;
}
sub entity
{
	my ($self,$en,$domain)=@_;
	return db::selectrow_hashref(qq/select * from er.entities(coalesce(?,0::int8),null,null,?)/,undef,$en,$domain);
}

sub update_row
{
	my ($selft,$id,$v1,$r,$v2)=@_;
	return db::do("update data set v1=?,r=?,v2=? where id=?",undef,$v1,$r,$v2,$id);
}
sub delete_row
{
	my ($selft,$id)=@_;
	return db::do("delete from data where id=?",undef,$id);
}

sub new_row
{
	my ($selft,$v1,$r,$v2)=@_;
	my $rv=db::do("insert into data (v1,r,v2) values (?,?,?)",undef,$v1,$r,$v2);
	return undef unless $rv;
	return db::selectval_scalar("select currval('data_id_seq')");
}


sub relations
{
	my ($self)=@_;
	return cached_array_ref($self,qq/select distinct r from data order by 1/);
}

sub init_schema
{
	db::do(qq/
create or replace view recv as
select distinct
rec.v2 as recid,
def.v1 as defvalue,
case when def.r ='наименование списка' then 'Список' when def.r ='наименование ИС' then 'Информационная система' when def.r='наименование структурного подразделения' then 'Структурное подразделение' when def.r='ФИО сотрудника' then 'Сотрудник' when def.r like '%учётной записи%' then 'Учётная запись' when def.r='наименование запроса сертификата PKI' then 'Запрос сертификата PKI' when def.r='наименование сертификата PKI' then 'Сертификат PKI' when def.r='наименование ключа PKI' then 'Ключ PKI' else null end as rectype
from  data rec
left join data def on def.v2=rec.v2 and (def.r like 'наименование %' or def.r like 'ФИО %' or def.r like 'имя входа учётной записи')
/);
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

sub newid
{
	my $self=shift;
	return db::selectval_scalar("select newid()");
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

sub membership()
{
	my ($self, $en)=@_;
	my $r=$self->cached_array_ref(q/
with z as (
select path[2: array_length(path,1)],path[array_length(path,1)] as id,shortest(s.t) as name from er.tree_from(?,er.keys('принадлежит%'),true,null,1) t
left join subjects s on s.e1=t.path[array_length(t.path,1)] and s.r=any(er.keys('наименование%','субъекты'))
group by path
)
select not exists (select 1 from z z2 where path[1: array_length(path,1)-1]=z.path) as leaf, * from z order by array_reverse(path)
/,$en);
	my $i={map {$_->{path}->[-1]=>$_->{name}} @$r};
	@$r=map {@{$_->{path}}=reverse @{$_->{path}};$_->{name}=$i->{$_->{path}->[-1]};$_->{names}=[map {$i->{$_}} @{$_->{path}}];$_} grep {$_->{leaf}} @$r;
	return {list=>$r};
}

sub authorization()
{
	my ($self, $en)=@_;
	my $r=$self->cached_array_ref(q/
select path[2: array_length(path,1)] as path,a.t as name from er.tree_from(?,array[er.key('входит в состав полномочия'),-er.key('уполномочен на')],null,null,1) t
left join authorities a on a.e1=t.path[array_length(t.path,1)] and a.r=any(er.keys('наименование%','полномочия'))
order by path
/,$en);
	return {list=>$r};
}

sub contact_info()
{
	my ($self, $en)=@_;
	return $self->cached_array_ref(q/
with m as (
select path[2: array_length(path,1)],path[array_length(path,1)] as id,shortest(s.t) as name from er.tree_from(?,er.keys('принадлежит%'),true) t
left join subjects s on s.e1=t.path[array_length(t.path,1)] and s.r=any(er.keys('наименование%','субъекты'))
group by path
)
select (array_agg_uniq(key))[1] as k, t, array_agg_uniq(m.id) as subjects, array_agg_uniq(m.name) as names
from m
join subjects p on p.r in (er.key('телефон'), er.key('email')) and p.e1=m.id
join er.keys k on k.id=p.r
group by t
order by max(m.path)
/,$en);
}

sub content()
{
	my ($self, $en)=@_;
	my $r=$self->cached_array_ref(q/
select path[2: array_length(path,1)] as path,shortest(s.t) as name from er.tree_from(?,er.keys('принадлежит%'),null,1,1) t
left join subjects s on s.e1=t.path[array_length(t.path,1)] and s.r=any(er.keys('наименование%','субъекты')||er.keys('полное имя%'))
group by path
order by path
/,$en);
	return {list=>$r};
}


sub synstatus
{
	my $self=shift;
	return read_table($self,qq\
select * from (
select def_is.v2 as isuid,def_is.v1 as isdef,to_char(sync_is.v1::timestamp with time zone,'yyyy-mm-dd hh24:mi:ss') as synctime  from data def_is
left join data sync_is on sync_is.r='синхронизация ИС' and sync_is.v2=def_is.v2
where def_is.r='наименование ИС'
) s order by synctime nulls last
\);
}

1;
