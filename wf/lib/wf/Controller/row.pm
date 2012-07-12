package wf::Controller::row;
use Moose;
use namespace::autoclean;
use Encode;

BEGIN { extends 'Catalyst::Controller::FormBuilder'; }

=head1 NAME

wf::Controller::row - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched wf::Controller::row in row.');
}


sub edit :Local :Form
{
	my ( $self, $c ) = @_;

	my $model=$c->model;
	my $id=$c->req->parameters->{id};

	my $row=$model->datarow($id);
	unless ($row)
	{
		$c->stash->{form}='';
		$c->stash->{msg}="Строка $id не существует";
		return;
	};
	my $v1=$c->req->{parameters}->{v1}||$row->{v1};
	my $r=$c->req->{parameters}->{r}||$row->{r};
	my $v2=$c->req->{parameters}->{v2}//$row->{v2};

	$c->stash->{confirmation}='update' if ($c->req->{parameters}->{_submit}//'') eq 'Сохранить';
	$c->stash->{confirmation}='delete' if ($c->req->{parameters}->{_submit}//'') eq 'Удалить';
	if (($c->req->{parameters}->{_submit}//'') eq 'Подтвердить')
	{
		my $rv;
		eval {$rv=$model->update_row($id,$v1,$r,$v2);};
		$c->stash->{msg}="Ошибка сохранения: ".db::errstr() unless $rv;
		if ($rv)
		{
			$c->response->redirect("?id=$id");
			$c->flash->{update_success}=1;
			return;
		};
	};
	if ($c->flash->{update_success})
	{
		delete $c->flash->{update_success};
		$c->stash->{msg}='Изменения сохранены';
	};

	
	$v1=$c->req->{parameters}->{selection} if ($c->req->{parameters}->{seltarget}//'') eq 'v1';
	$v2=$c->req->{parameters}->{selection} if ($c->req->{parameters}->{seltarget}//'') eq 'v2';

	my ($def1,$rt1)=$model->recdef($v1);
	my ($def2,$rt2)=$model->recdef($v2);
	my $data=$c->stash->{data}={
		row=>$row,
		p=>$c->req->{parameters},
		v1=>$v1
	};
	my $form=$self->formbuilder;

	$form->selectnum(0);
	$form->field(name => 'id', label=>'id', value=>$id,readonly=>1);
	$form->field(name => 'v1', label=>'v1', value=>$v1, size=>1.22*length(decode("utf8",$v1)),recsel=>{rectype=>$rt1,anchor=>$def1?"$def1, $rt1":"Выбрать", target=>'v1'});
	$form->field(name => 'r', label=>'r', value=>$r, options => $model->relations());
	$form->field(name => 'v2', label=>'v2', value=>$v2, size=>1.22*length(decode("utf8",$v2)),recsel=>{rectype=>$rt2,anchor=>$def2?"$def2, $rt2":"Выбрать", target=>'v2'});

	$form->submit(['Сохранить','Удалить']);
	$form->method('post');
	$form->action("?id=$id");

	$form->field(name=>'v1',value=>$v1,force=>1);
	$form->field(name=>'r',value=>$r,force=>1);
	$form->field(name=>'v2',value=>$v2,force=>1);

	$c->stash->{heading}='Изменение строки';
	$data->{f}=$form;
}

sub delete :Local :Form
{
	my ( $self, $c ) = @_;

	my $model=$c->model;
	my $id=$c->req->parameters->{id};

	$c->stash->{form}='';
	my $row=$model->datarow($id);
	unless ($row or $c->flash->{delete_success})
	{
		$c->stash->{data}{test}{text}="Строка $id не существует";
		return;
	};
	if (($c->req->{parameters}->{_submit}//'') eq 'Подтвердить')
	{
		my $rv;
		eval {$rv=$model->delete_row($id);};
		$c->stash->{data}{test}{text}="Ошибка удаления: ".db::errstr() unless $rv;
		$rv=1;
		if ($rv)
		{
			$c->response->redirect("?id=$id");
			$c->flash->{delete_success}=1;
			return;
		};
	};
	if ($c->flash->{delete_success})
	{
		delete $c->flash->{delete_success};
		$c->stash->{data}{test}{text}="Строка $id удалена";
	};
};
=head1 AUTHOR

Pushkinsv

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#__PACKAGE__->meta->make_immutable;

1;
