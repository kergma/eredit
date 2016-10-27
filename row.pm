package eredit::row;
use Moose;
use namespace::autoclean;
use utf8;
no warnings 'uninitialized';

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


sub eredit :Path('er/edit')
{
	my ( $self, $c ) = @_;

	my $m=$c->model('er');
	my $p=$c->req->parameters;
	my $table=ref $p->{table} eq 'ARRAY'?$p->{table}->[0]:$p->{table};
	$p->{$_}=$p->{$_}->[-1] foreach grep {ref $p->{$_} eq 'ARRAY'} keys %$p;
	$p->{$p->{seltarget}}=$p->{selection} if $p->{seltarget};

	$c->stash->{heading}='Изменение строки';
	$c->stash->{heading}='Создание строки' unless $p->{row};

	if (($p->{_submit}//'') eq 'Вернуться')
	{
		$c->response->redirect($p->{redir});
		return;
	};
	if ($c->flash->{row_update_success})
	{
		$c->stash->{success}=$c->flash->{row_update_success};
		delete $c->flash->{row_update_success};
	};
	my $row =$m->row($table,$p->{row})//[];
	$c->stash->{error}="строка $table: $p->{row} не существует" and return if $p->{row} and @$row<1;

	my $storages=$m->storages();
	if (@$row<1)
	{
		my $storage=(grep {$_->{table} eq $p->{table}} @$storages)[0];
		$row=[{column=>'table',value=>$storage->{table}},map {{column=>$_}} @{$storage->{columns}}];
	};

	$c->stash->{r}=$row;
	$c->stash->{display}->{order}=[qw/row error success confirm/];
	my $form=$c->stash->{row}->{form}=CGI::FormBuilder->new(
		method=>"post",
		action=>"?$c->{request}->{env}->{QUERY_STRING}",
		submit=>[grep {$_} ('Сохранить',defined $p->{row} && 'Удалить',$p->{redir}&&'Вернуться')],
		fieldsubs=>1,
		selectnum=>0
	);

	$p->{$_->{column}}//=$_->{value} foreach @$row;
	foreach my $r (@$row)
	{
		$form->field(name=>$r->{column},label=>$r->{column}, value=>$p->{$r->{column}}, readonly=>$r->{column} eq 'row'||undef);
		$form->field(name=>$r->{column}, renderer=>'ensel') if $r->{column}=~'^e\d+';
		$form->field(name=>$r->{column}, renderer=>'keysel') if $r->{column} eq 'r';
	};
	$form->field(name=>'table',options=>[map {$_->{table}} @$storages], onchange=>'this.form.submit()');
	
	if (($p->{_submit}//'') eq 'Сохранить' or ($p->{_submit}//'') eq 'Удалить')
	{
		$c->stash->{error}='не задана таблица строки' and return unless $p->{table};
		my $message="Подтвердите сохранение изменений в строке $table:$p->{row}";
		$message.=" с переносом в таблицу $p->{table}" if $table ne $p->{table};
		$message="Подтвердите создание строки в таблице $p->{table}" unless $p->{row};
		$message="Подтвердите удаление строки $table:$p->{row}" if $p->{_submit} eq 'Удалить';
		$c->stash->{confirm}={
			text=>[$message],
			form=>CGI::FormBuilder->new(
				method=>"post",
				action=>"",
				submit=>['Подтвердить','Отказаться'],
				fieldsubs=>1
			),
		};
		$p->{confirm_action}=$p->{_submit};
		$c->stash->{confirm}->{form}->field(name=>$_,type=>'hidden',value=>$p->{$_}) foreach grep {$_!~/^_submit/} keys %$p;
	};

	if (($p->{_submit}//'') eq 'Подтвердить')
	{
		delete $p->{table} if $p->{confirm_action} eq 'Удалить';
		my $rv=$m->row_update($row,$p);
		$c->stash->{error}->{text}="Ошибка сохранения: ".db::errstr() unless $rv;
		if ($rv)
		{
			$c->response->redirect($p->{redir}) if $p->{redir};
			return if $p->{redir};
			$c->response->redirect("?table=$rv->[-1]->{table}&row=$rv->[-1]->{row}");
			$c->flash->{row_update_success}={text=>["Изменения сохранены",map{"$_->{table}:$_->{row} $_->{action}"} @$rv ]};
			return;
		};
	};
}
sub edit :Local
{
	my ( $self, $c ) = @_;
	$c->stash->{heading}='Изменение строки';

	my $m=$c->model;
	my $p=$c->req->parameters;
	$p->{$_}=shift @{$p->{$_}} foreach grep {ref $p->{$_} eq 'ARRAY'} keys %$p;
	$p->{$p->{seltarget}}=$p->{selection} if $p->{seltarget};

	if (($p->{_submit}//'') eq 'Вернуться')
	{
		$c->response->redirect($p->{redir});
		return;
	};
	if ($c->flash->{row_update_success})
	{
		$c->stash->{success}=$c->flash->{row_update_success};
		delete $c->flash->{row_update_success};
	};
	my $row=$m->datarow($p->{id});
	unless ($row)
	{
		$c->stash->{error}="Строка $p->{id} не существует";
		return;
	};
	%$p=(%$p,%{$row}) unless $p->{_submitted};
	$c->stash->{display}->{order}=[qw/row error success confirm/];
	my $form=$c->stash->{row}->{form}=CGI::FormBuilder->new(
		method=>"post",
		action=>"?$c->{request}->{env}->{QUERY_STRING}",
		submit=>$p->{redir}?['Сохранить','Удалить','Вернуться']:['Сохранить','Удалить'],
		fieldsubs=>1,
		selectnum=>0
	);
	
	my ($def1,$rt1)=$m->recdef($p->{v1});
	my ($def2,$rt2)=$m->recdef($p->{v2});

	$form->field(name => 'id', label=>'id', value=>$p->{id},readonly=>1);
	$form->field(name => 'v1', label=>'v1', value=>$p->{v1}, size=>1.22*length($p->{v1}//''),rs_rectype=>$rt1,rs_recdef=>$def1,renderer=>'recsel');
	$form->field(name => 'r', label=>'r', value=>$p->{r}, options => $m->relations());
	$form->field(name => 'v2', label=>'v2', value=>$p->{v2}, size=>1.22*length($p->{v2}//''),rs_rectype=>$rt2,rs_recdef=>$def2,renderer=>'recsel');
	if (($p->{_submit}//'') eq 'Сохранить' or ($p->{_submit}//'') eq 'Удалить')
	{
		$c->stash->{confirm}={
			text=>[($p->{_submit}//'') eq 'Сохранить'?"Подтвердите сохранение изменений в строке $p->{id}":"Подтвердите удаление строки $p->{id}"],
			form=>CGI::FormBuilder->new(
				method=>"post",
				action=>"",
				submit=>['Подтвердить','Отказаться'],
				fieldsubs=>1
			),
		};
		$p->{confirm_action}=$p->{_submit};
		$c->stash->{confirm}->{form}->field(name=>$_,type=>'hidden',value=>$p->{$_}) foreach grep {$_!~/^_submit/} keys %$p;
	};

	if (($p->{_submit}//'') eq 'Подтвердить')
	{
		if ($p->{confirm_action} eq 'Удалить')
		{
			$c->response->redirect("/row/delete?id=$p->{id}&_submit=Подтвердить&redir=$p->{redir}");
			return;
		};
		my $rv;
		eval {$rv=$m->update_row($p->{id},$p->{v1},$p->{r},$p->{v2});};
		$c->stash->{error}->{text}="Ошибка сохранения: ".db::errstr() unless $rv;
		if ($rv)
		{
			$c->response->redirect($p->{redir}) if $p->{redir};
			return if $p->{redir};
			$c->response->redirect("?id=$p->{id}");
			$c->flash->{row_update_success}={text=>"Изменения сохранены"};
			return;
		};
	};

}

sub delete :Local
{
	my ( $self, $c ) = @_;

	my $model=$c->model;
	my $id=$c->req->parameters->{id};

	my $redir;
	$redir=$c->req->parameters->{redir} if $c->req->parameters->{redir};

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
			$c->response->redirect($redir) if $redir;
			return if $redir;
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

sub create :Local
{
	my ( $self, $c ) = @_;

	my $model=$c->model;

	my $redir;
	$redir=$c->req->parameters->{redir} if $c->req->parameters->{redir};

	my $data=$c->stash;
	if (($c->req->{parameters}->{_submit}//'') eq 'Отказаться')
	{

		$c->response->redirect($redir) if $redir;
		return;
	};
	if (($c->req->{parameters}->{_submit}//'') eq 'Подтвердить' or (defined($c->req->parameters->{confirm}) and !$c->req->parameters->{confirm}))
	{
		my $id;
		eval {$id=$model->new_row($c->req->parameters->{v1},$c->req->parameters->{r},$c->req->parameters->{v2})};
		unless ($id)
		{
			$data->{result}={
				text=>qq\Ошибка создания строки: \.db::errstr()
			};
			return;
		};
		
		$data->{result}={
			text=>qq\Строка создана с идентификатором $id (<a href="/row/edit?id=$id">Редактировать</a>)\
		};
		$redir="/row/edit?id=$id" unless defined $c->req->parameters->{redir};
		$c->response->redirect($redir) if $redir;
		return;
	};

	if ($c->req->parameters->{confirm} or !defined($c->req->parameters->{confirm}))
	{
		
		$data->{text}="Подтвердите создание строки";
		$data->{form}->{form}=CGI::FormBuilder->new(
			method=>"post",
			action=>"?$c->{request}->{env}->{QUERY_STRING}",
			submit=>['Подтвердить','Отказаться'],
			fieldsubs=>1
		);
		$data->{confirm}={
			v1=>$c->req->parameters->{v1},
			r=>$c->req->parameters->{r},
			v2=>$c->req->parameters->{v2},
			display=>{
				order=>[qw/v1 r v2/],
				renderer=>'table2'
			},

		};
		$data->{display}={order=>[qw/text confirm form /]};
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
