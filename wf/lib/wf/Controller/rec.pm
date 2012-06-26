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
		recid=>'Запись',
		defvalue=>'Определение',
		rectype=>'Тип',
		#order_=>[qw/recid defvalue rectype/],
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
