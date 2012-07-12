package wf::Controller::rec;
use Moose;
use namespace::autoclean;

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
	$filter{rectype}=$form->field('rectype');
	$filter{limit}=$form->field('limit');

	$form->field(name => $_, value=>$c->req->{parameters}->{$_}, type=>'hidden') foreach grep {!defined $filter{$_}} keys %{$c->req->{parameters}};

	$c->stash->{data}={records=>$model->search_records(\%filter),f=>\%filter};
	$c->stash->{data}->{records}->{display_}= {
		recref=>'Запись',
		defvalue=>'Определение',
		rectype=>'Тип',
		order_=>[qw/recref defvalue rectype/],
	};
	my $selaction=$c->req->{parameters}->{selaction};
	if ($selaction)
	{
		$_->{recref}=qq\<a href="javascript:;" onclick="f=document.forms[0];f.selection.value='$_->{recid}';f.action='$selaction';f.submit()">$_->{recid}</a>\ foreach @{$c->stash->{data}->{records}->{rows}};
	}
	else
	{
		$_->{recref}=qq(<a href="/rec/view?id=$_->{recid}">$_->{recid}</a>) foreach @{$c->stash->{data}->{records}->{rows}};
	};
	$c->stash->{data}->{p}=$c->req->{parameters};

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
		rec=>{
			rows=>$model->read_record($id),
			display_=>{
				v1=>'Значение',
				r=>'Связь',
				v2=>'Значение',
				c1=>'Имя/значение',
				c2=>'Имя/значение',
				e=>'Р',
				d=>'У',
				#order_=>[qw/v1 r v2/]
				order_=>[qw/e d c1 c2/]
			},
		}
	};
	($data->{rec}->{def}->{defvalue},$data->{rec}->{def}->{rectype})=$model->recdef($id);
	$c->stash->{heading}="$data->{rec}->{def}->{defvalue} ($data->{rec}->{def}->{rectype})";
	foreach my $r (@{$data->{rec}->{rows}})
	{
		($r->{c1},$r->{c2})=grep {$_} (
			$r->{v1} && $r->{refdef}?qq\<a href="/rec/view?id=$r->{v1}">$r->{refdef}</a>\:$r->{v1},
			$r->{r},
			$r->{v2} && $r->{refdef}?qq\<a href="/rec/view?id=$r->{v2}">$r->{refdef}</a>\:$r->{v2},
		);
		$r->{e}=qq\<a href="/row/edit?id=$r->{id}">*</a>\;
	};
}

=head1 AUTHOR

Pushkinsv

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#__PACKAGE__->meta->make_immutable;

1;
