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
