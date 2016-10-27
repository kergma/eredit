package eredit::Controller::er;
use Moose;
use namespace::autoclean;
use utf8;

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

	my $model=$c->model('er');

	$c->stash->{heading}='Выбор записи';

	my $p=$c->req->{parameters};
	$p->{$_}=$p->{$_}->[-1] foreach grep {ref $p->{$_} eq 'ARRAY'} keys %$p;

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

	$form->field(name => $_, value=>$p->{$_}, type=>'hidden') foreach grep {my $p=$_;! grep {$_ eq $p} $form->fields} keys %$p;

	$_||=undef foreach values %$p;

	$c->stash->{data}={entities=>$model->entities($p)};
	$_->{type}=sprintf qq\<span title="%s">%s</span>\,join(', ',@{$_->{types}}[0 .. @{$_->{types}}-2]),$_->{types}->[-1] foreach @{$c->stash->{data}->{entities}->{rows}};
	$c->stash->{data}->{entities}->{display}= {
		nameref=>'Имя',
		type=>'Тип',
		en=>'Идентификатор',
		order=>[qw/nameref type en/],
	};
	($_->{name},$_->{namehint})=($_->{names}->[0]//'&ltбез имени&gt',join(', ',@{$_->{names}}[1 .. @{$_->{names}}-1])) foreach @{$c->stash->{data}->{entities}->{rows}};
	if ($p->{selaction})
	{
		$_->{nameref}=qq\<a href="javascript:;" onclick="f=document.forms[0];f.selection.value='$_->{en}';f.action='$p->{selaction}';f.submit()" title="$_->{namehint}">$_->{name}</a>\ foreach @{$c->stash->{data}->{entities}->{rows}};
	}
	else
	{
		$_->{nameref}=sprintf qq\<a href="view?en=%s" title="%s">%s</a>\,$_->{en},$_->{namehint},$_->{name} foreach @{$c->stash->{data}->{entities}->{rows}};
	};
	$c->stash->{data}->{p}=$c->req->{parameters};
	$c->stash->{display}={order=>[qw/formbuilder data/]};

}

sub view:Local
{
	my ( $self, $c ) = @_;

	my $model=$c->model('er');
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
				e=>'Строка',
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
			$r->{e1}==$en?'':sprintf(qq\<a href="view?en=%s">%s</a>\,$r->{e1},$r->{name1}||'&ltбез имени&gt'),
			$r->{key},
			$r->{e2}?sprintf(qq\<a href="view?en=%s">%s</a>\,$r->{e2},$r->{name2}||'&ltбез имени&gt'):$r->{value}
		);
		$r->{e}=qq\<a href="edit?row=$r->{row}&table=$r->{table}&redir=view%3Fen=$en">$r->{table}:$r->{row}</a>\;
		$data->{tables}->{$r->{table}}++;
	};
	$data->{newrow}->{text}=sprintf qq\<a href="edit?e1=$en&e2=$en&table=%s&redir=view%%3Fen=$en">Новая строка</a>\,(sort {$data->{tables}->{$b} <=> $data->{tables}->{$a}} keys %{$data->{tables}})[0];

	$data->{more}={text=>qq\<a href="/subject/$en">Просмотр</a>\} if 'субъект'~~$data->{entity}->{types};
	$data->{more}={text=>qq\<a href="/pki/view?record=$en">Просмотр</a>\} if $data->{rec}->{def}->{rectype} =~ /PKI$/;
}

sub create:Local
{
	my ( $self, $c ) = @_;

	my $model=$c->model('er');
	my $id=$model->generate_id();
	$c->response->headers->header(cache_control => "no-cache");
	$c->response->redirect("view?en=$id",302);
}

sub edit :Local
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
=head1 AUTHOR

Pushkinsv

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

#__PACKAGE__->meta->make_immutable;

1;
