package wf::Controller::rec;
use Moose;
use namespace::autoclean;

no warnings 'uninitialized';

BEGIN {extends 'Catalyst::Controller::FormBuilder'; }

=head1 NAME

wf::Controller::rec - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched wf::Controller::rec in rec.');
}

sub ersearch:Local :Form
{
	my ( $self, $c ) = @_;

	my $model=$c->model;

	$c->stash->{heading}='Выбор записи';

	my $p=$c->req->{parameters};

	$p->{limit}//=3000;
	my $form=$self->formbuilder;
	$form->selectnum(0);
	$form->field(name => 'selection', type=>'hidden');
	$form->field(name => 'en', label=>'Ид', value=>$p->{en});
	$form->field(name => 'name', label=>'Имя', value=>$p->{name});
	$form->field(name => 'type', label=>'Тип', options => $model->types(), value=>$p->{type});
	$form->field(name => 'domain', label=>'Домен', options => $model->domains(), value=>$p->{domain});
	$form->field(name => 'limit', label=>'Ограничить',value=>$p->{limit});
	$form->submit('Выбрать');
	$form->method('post');
	
	$_||=undef foreach values %$p;

	$c->stash->{data}={entities=>$model->entities($p)};
	$_->{type}=sprintf qq\<span title="%s">%s</span>\,join(', ',@{$_->{types}}[0 .. @{$_->{types}}-2]),$_->{types}->[-1] foreach @{$c->stash->{data}->{entities}->{rows}};
	$c->stash->{data}->{entities}->{display}= {
		name=>'Имя',
		type=>'Тип',
		en=>'Идентификатор',
		order=>[qw/name type en/],
	};
	if ($p->{selaction})
	{
		$_->{recref}=qq\<a href="javascript:;" onclick="f=document.forms[0];f.selection.value='$_->{recid}';f.action='$p->{selaction}';f.submit()">$_->{defvalue}</a>\ foreach @{$c->stash->{data}->{records}->{rows}};
	}
	else
	{
		$_->{name}=sprintf qq\<a href="/rec/erview?en=%s" title="%s">%s</a>\,$_->{en},join(', ',@{$_->{names}}[1 .. @{$_->{names}}-1]),$_->{names}->[0]//'&ltбез имени&gt' foreach @{$c->stash->{data}->{entities}->{rows}};
	};
	$c->stash->{data}->{p}=$c->req->{parameters};
	$c->stash->{display}={order=>[qw/formbuilder data/]};

}
sub search:Local :Form
{
	my ( $self, $c ) = @_;

	my $model=$c->model;

	my $form=$self->formbuilder;
	$c->stash->{heading}='Выбор записи';

	$form->selectnum(0);
	$form->field(name => 'selection', type=>'hidden');
	$form->field(name => 'recid', label=>'Запись');
	$form->field(name => 'defvalue', label=>'Определение');
	$form->field(name => 'rectype', label=>'Тип', options => $model->rectypes());
	$form->field(name => 'limit', label=>'Ограничить',value=>3000);
	$form->submit('Выбрать');
	$form->method('post');

	my %filter=(_submitted=>0,_submit=>0);
	$filter{recid}=$form->field('recid');
	$filter{defvalue}=$form->field('defvalue');
	$filter{rectype}=$form->field('rectype')//'';
	$filter{rectype}=['Ключ PKI','Запрос сертификата PKI','Сертификат PKI'] if $filter{rectype} eq 'Объект PKI';
	$filter{related}=$c->req->{parameters}->{related} if $c->req->{parameters}->{related};
	$filter{limit}=$form->field('limit');

	$form->field(name => $_, value=>$c->req->{parameters}->{$_}, type=>'hidden') foreach grep {!defined $filter{$_}} keys %{$c->req->{parameters}};

	$c->stash->{data}={records=>$model->search_records(\%filter),f=>\%filter};
	$c->stash->{data}->{records}->{display}= {
		recref=>'Определение',
		rectype=>'Тип',
		recid=>'Запись',
		order=>[qw/recref rectype recid/],
	};
	my $selaction=$c->req->{parameters}->{selaction};
	if ($selaction)
	{
		$_->{recref}=qq\<a href="javascript:;" onclick="f=document.forms[0];f.selection.value='$_->{recid}';f.action='$selaction';f.submit()">$_->{defvalue}</a>\ foreach @{$c->stash->{data}->{records}->{rows}};
	}
	else
	{
		$_->{recref}=sprintf qq(<a href="/rec/view?id=%s">%s</a>),$_->{recid}//'',$_->{defvalue}//'&ltне определено&gt' foreach @{$c->stash->{data}->{records}->{rows}};
	};
	$c->stash->{data}->{p}=$c->req->{parameters};
	$c->stash->{display}={order=>[qw/formbuilder data/]};

}

sub edit:Local:Form
{
	my ( $self, $c ) = @_;

	my $model=$c->model;

	my $form=$self->formbuilder;
	$c->stash->{heading}='Изменение записи';
	my $data=$c->stash->{data}={rec=>$model->read_record($c->req->parameters->{id})};

}

sub view:Local
{
	my ( $self, $c ) = @_;

	my $model=$c->model;
	my $id=$c->req->parameters->{id};

	my $data=$c->stash->{data}={
		id=>{text=>$id},
		rec=>{
			rows=>$model->read_record($id),
			display=>{
				v1=>'Значение',
				r=>'Связь',
				v2=>'Значение',
				c1=>'Имя/значение',
				c2=>'Имя/значение',
				e=>'Ред',
				order=>[qw/e c1 c2/]
			},
		},
		newrow=>{
			text=>qq\<a href="/row/create?v2=$id&redir=/rec/view%3Fid=$id">Новая строка</a>\
		},
		display=>{order=>[qw/id rec newrow more/]},
	};
	($data->{rec}->{def}->{defvalue},$data->{rec}->{def}->{rectype})=$model->recdef($id);
	$c->stash->{heading}=sprintf "%s (%s)",$data->{rec}->{def}->{defvalue}//'',$data->{rec}->{def}->{rectype}//'';
	foreach my $r (@{$data->{rec}->{rows}})
	{
		($r->{c1},$r->{c2})=grep {$_} (
			$r->{v1} && $r->{refdef}?qq\<a href="/rec/view?id=$r->{v1}">$r->{refdef}</a>\:$r->{v1},
			$r->{r},
			$r->{v2} && $r->{refdef}?qq\<a href="/rec/view?id=$r->{v2}">$r->{refdef}</a>\:$r->{v2},
		);
		$r->{e}=qq\<a href="/row/edit?id=$r->{id}&redir=/rec/view%3Fid=$id">$r->{id}</a>\;
	};
	$data->{more}={text=>qq\<a href="/pki/view?record=$id">Просмотр</a>\} if $data->{rec}->{def}->{rectype} =~ /PKI$/;
}

sub erview:Local
{
	my ( $self, $c ) = @_;

	my $model=$c->model;
	my $en=$c->req->parameters->{en};

	my $data=$c->stash->{data}={
		en=>{text=>$en},
		rec=>{
			rows=>$model->record_of($en),
			display=>{
				v1=>'Значение',
				r=>'Связь',
				v2=>'Значение',
				c1=>'Имя/значение',
				c2=>'Имя/значение',
				e=>'Ред',
				order=>[qw/e c1 c2/]
			},
		},
		display=>{order=>[qw/en rec newrow more/]},
	};
	$data->{entity}=$model->entity($en);
	$c->stash->{heading}=sprintf "%s (%s)",$data->{entity}->{names}->[0],$data->{entity}->{types}->[-1];
	$data->{en}->{text}=join(', ',$en, @{$data->{entity}->{names}}[1 .. @{$data->{entity}->{names}}-1],@{$data->{entity}->{types}});
	foreach my $r (@{$data->{rec}->{rows}})
	{
		($r->{c1},$r->{c2})=grep {$_} (
			$r->{e1}==$en?'':sprintf(qq\<a href="/rec/erview?en=%s">%s</a>\,$r->{e1},$r->{name1}||'&ltбез имени&gt'),
			$r->{key},
			$r->{e2}?sprintf(qq\<a href="/rec/erview?en=%s">%s</a>\,$r->{e2},$r->{name2}||'&ltбез имени&gt'):$r->{value}
		);
		$r->{e}=qq\<a href="/row/eredit?row=$r->{row}&table=$r->{table}&redir=/rec/erview%3Fen=$en">$r->{table}:$r->{row}</a>\;
		$data->{tables}->{$r->{table}}++;
	};
	$data->{newrow}->{text}=sprintf qq\<a href="/row/eredit?e1=$en&e2=$en&table=%s&redir=/rec/erview%%3Fen=$en">Новая строка</a>\,(sort {$data->{tables}->{$b} <=> $data->{tables}->{$a}} keys %{$data->{tables}})[0];
	$data->{more}={text=>qq\<a href="/pki/view?record=$en">Просмотр</a>\} if $data->{rec}->{def}->{rectype} =~ /PKI$/;
}


sub create:Local
{
	my ( $self, $c ) = @_;

	my $model=$c->model;
	my $id=$model->newid();
	$c->response->headers->header(cache_control => "no-cache");
	$c->response->redirect("/rec/view?id=$id",302);
}
=head1 AUTHOR

Pushkinsv

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#__PACKAGE__->meta->make_immutable;

1;
