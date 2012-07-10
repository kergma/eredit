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
	$form->field(name => 'recid', label=>'Запись');
	$form->field(name => 'defvalue', label=>'Определение');
	$form->field(name => 'rectype', label=>'Тип', options => $model->rectypes());
	$form->field(name => 'limit', label=>'Ограничить',value=>3000);
	$form->submit('Выбрать');
	$form->method('post');

	my %filter;
	$filter{recid}=$form->field('recid');
	$filter{defvalue}=$form->field('defvalue');
	$filter{rectype}=$form->field('rectype');
	$filter{limit}=$form->field('limit');

	$c->stash->{data}={records=>$model->search_records(\%filter),f=>\%filter};
	$c->stash->{data}->{records}->{display_}= {
		recref=>'Запись',
		defvalue=>'Определение',
		rectype=>'Тип',
		order_=>[qw/recref defvalue rectype/],
	};
	$_->{recref}=qq(<a href="/rec/view?id=$_->{recid}">$_->{recid}</a>) foreach @{$c->stash->{data}->{records}->{rows}};

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

	my $data=$c->stash->{data}={
		rec=>{
			rows=>$model->read_record($c->req->parameters->{id}),
			def=>$model->recdef($c->req->parameters->{id}),
			display_=>{
				v1=>'Значение',
				r=>'Связь',
				v2=>'Значение',
				c1=>'Имя/значение',
				c2=>'Имя/значение',
				#order_=>[qw/v1 r v2/]
				order_=>[qw/c1 c2/]
			},
		}
	};
	$c->stash->{heading}="$data->{rec}->{def}->{defvalue} ($data->{rec}->{def}->{rectype})";
	foreach my $r (@{$data->{rec}->{rows}})
	{
		($r->{c1},$r->{c2})=grep {$_} (
			$r->{v1} && $r->{refdef}?qq\<a href="/rec/view?id=$r->{v1}">$r->{refdef}</a>\:$r->{v1},
			$r->{r},
			$r->{v2} && $r->{refdef}?qq\<a href="/rec/view?id=$r->{v2}">$r->{refdef}</a>\:$r->{v2},
		);
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
