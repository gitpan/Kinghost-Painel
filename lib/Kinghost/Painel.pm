package Kinghost::Painel;

        use strict;
		use warnings 'all';
		use Win32::ASP;
		use Win32::OLE;
		use WWW::Mechanize;
        use HTML::TreeBuilder::XPath;
        use HTML::Entities;
        use JSON;
        
        my $statusLogin;
        my $entitieschars;
        my $mech;
	
	sub new
        {
            my $class = shift;
            my $self = {

            };
            
            $statusLogin = 0;
            $entitieschars = 'ÁÍÓÚÉÄÏÖÜËÀÌÒÙÈÃÕÂÎÔÛÊáíóúéäïöüëàìòùèãõâîôûêÇç';
            $mech = WWW::Mechanize->new;
            
            bless $self, $class;           
            return $self, $class;
        } 
        
        sub logar
        {
            my($self, $email, $senha) = @_;
            my $html;
            $mech->post("https://painel2.kinghost.net/login.php");
            if($mech->success())
            {
                    if($mech->status() == 200)
                    {
                            # loga no painel
                            $mech->submit_form(
                                    form_id => "formLogin",
                                    fields      => {
                                            email => $email,
                                            senha => $senha,
                                    }
                            );
                            $html = $mech->content;
                            $mech->update_html( $html );
                            my $tree = HTML::TreeBuilder::XPath->new;
                            $tree->parse( $html );
                            # resposta da tentiva de cadastro
                            my $respostaloga = $tree->findnodes( '//body' )->[0]->as_HTML;
                            
                            if(index($respostaloga, "abaixo para acessar o Painel de Controle") == -1)
                            {
                                $statusLogin = 1;
                                return "logged";
                            }
                            else
                            {
                                return "invalid login";
                            }
                     }
                     elsif($mech->status() == 404)
                     {
                         return "not found";
                     }
                     else
                     {
                         return "unknow HTTP error";
                     }
            }
            else
            {
                return "connection error";
            }
            
        }
        
        
        sub novoCliente
        {
            my($self, $empresa, $nome, $tipoPessoa, $cpfcnpj, $email, $emailcobranca, $senha, $senhaConfimacao, $telefone, $fax, $cep, $endereco, $cidade, $estado) = @_;
            my %resposta;
            if($statusLogin)
            {
                my $html;
                my $table_rows;
                
                # cria cliente
                $mech->post("https://painel2.kinghost.net/cliente.php?editar");
                $mech->submit_form(
                    form_id => "formEdit",
                    fields      => {
                        acao => "sub_cliente",
                        subacao => "edita",
                        id_sub_cliente => 0,
                        'dados[TipoPessoa]' => $tipoPessoa, 
                        'dados[CpfCnpj]' => $cpfcnpj,
                        'dados[Empresa]' => encode_entities($empresa, $entitieschars),
                        'dados[Nome]' => encode_entities($nome, $entitieschars),
                        'dados[Email]' => $email, # nao pode repetir
                        'dados[EmailCobranca]' => $emailcobranca, # nao pode repetir
                        'dados[SenhaPainel]' => $senha,
                        'senha1' => $senhaConfimacao,
                        'dados[Fone]' => $telefone,
                        'dados[Fax]' => $fax,
                        'dados[CEP]' => $cep,
                        'dados[Endereco]' => $endereco,
                        'dados[Cidade]' => $cidade,
                        'dados[Estado]' => $estado,
                        'dados[LimiteMapeamento]' => 1,
                        'dados[LimiteSubdominio]' => 1,
                        'dados[LimiteMysql]' => 1,
                        'dados[LimiteMssql]' => 0,
                        'dados[LimitePgsql]' => 1,
                        'dados[LimiteFirebird]' => 0,
                        'dados[LimiteFTPADD]' => 0,
                        'dados[UniBox]' => "INATIVO",
                        'dados[AcessoFTP]' => "INATIVO",
                        'dados[AcessoDownloadBackup]' => "INATIVO",
                        'dados[AcessoLogotipoWebmail]' => "INATIVO",
                        'dados[AcessoCupomGoogleAdwords]' => "ATIVO",
                    }
                );	
                if($mech->success())
                {
                    if($mech->status() == 200)
                    {
                        $html = $mech->content;
                        $mech->update_html( $html );
                        my $tree = HTML::TreeBuilder::XPath->new;
                        $tree->parse( $html );
                        # resposta da tentiva de cadastro
                        my $respostaSalvaCliente = $tree->findnodes( '//body' )->[0]->as_HTML;
                        # salvo
                        if(index($respostaSalvaCliente, "Cliente") != -1 && index($respostaSalvaCliente, "Salvo") != -1)
                        {			
                            $mech->get("https://painel2.kinghost.net/cliente.php");
                            $html = $mech->content;
                            $mech->update_html( $html );
                            
                            my $tree = HTML::TreeBuilder::XPath->new;
                            $tree->parse( $html );
                            
                            $table_rows = $tree->findnodes( '//table[@class="default tralt"]/tr' );
                            
                            foreach my $row ( $table_rows->get_nodelist )
                            {
                                my $tree_tr = HTML::TreeBuilder::XPath->new;
                                $tree_tr->parse( $row->as_HTML  );
                                
                                my $empresaR = $tree_tr->findvalue( '//td[1]' );
                                my $nomeR = $tree_tr->findvalue( '//td[2]' );
                                my $linkR = $tree_tr->findvalue( '//td[4]//a[1]' );
                                my $codigo = $row->as_HTML;
                                if(index($nomeR, $nome) != -1)
                                {
                                        my @codigo = split(/f_cliente=/, $codigo);
                                        @codigo = split(/"/, $codigo[1]); #"
                                        %resposta = (
                                                status  => "sucesso",
                                                resposta =>  "registrado",
                                                codigo =>  $codigo[0],
                                                nome => encode_entities($nome, $entitieschars),
                                         );
                                }
                                $tree_tr->delete;
                            }
                        }
                        # e-mail em uso
                        elsif(index($respostaSalvaCliente, "existe") != -1 && index($respostaSalvaCliente, "cliente") != -1 && index($respostaSalvaCliente, "cadastrado") != -1 && index($respostaSalvaCliente, "e-mail") != -1)
                        {
                            %resposta = (
                                status  => "erro",
                                resposta =>  "E-mail em uso",
                            );
                        }
                        else
                        {
                            # mostra resultado desconhecido	
                            %resposta = (
                                status  => "erro",
                                resposta =>  $respostaSalvaCliente,
                            );
                        }
                        
                        my $json = \%resposta;
                        my $json_text = to_json($json);
                        
                        return $json_text;
                    }
                    elsif($mech->status() == 404)
                    {
                        %resposta = (
                            status  => "erro",
                            resposta =>  "not found",
                            url =>  $mech->uri(),
			);
			my $json = \%resposta;
                        my $json_text = to_json($json);
                        return $json_text;
                    }
                    else
                    {
                        %resposta = (
                            status  => "erro",
                            resposta =>  "unknow HTTP error",
                            url =>  $mech->uri(),
			);
			my $json = \%resposta;
                        my $json_text = to_json($json);
                        return $json_text;
                    }
                }
            }
            else
            {
                %resposta = (
                    status  => "erro",
                    resposta =>  "efetue login primeiro",
                );
                
                my $json = \%resposta;
                my $json_text = to_json($json);
                            
                return $json_text;
            }
        }
        
        
        sub novoDominio
        {
            my($self, $plano, $cliente, $pagoate, $dominio, $senha, $plataforma, $webmail) = @_;
            my %resposta;
            if($statusLogin)
            {
                my $html;
                my $table_rows;
                
                # cria dominio
		$mech->post("https://painel2.kinghost.net/painel.inserir.php");
		$mech->submit_form(
			form_id => "novoDominio",
			fields      => {
				acao => "dominio",
				subacao => "adicionar",
				'dados[plano_id]' => "$plano",
				'dados[id_sub_cliente]' => "$cliente",
				'dados[pagoate]' => "$pagoate",
				'dados[dominio]' => "$dominio",
				'dados[senha]' => "$senha",
				'dados[plataforma]' => "$plataforma",
				'dados[webmail]' => "$webmail",
			}
		);
		if($mech->success())
		{
			if($mech->status() == 200)
			{
				$html = $mech->content;
				$mech->update_html( $html );
				my $tree = HTML::TreeBuilder::XPath->new;
				$tree->parse( $html );
				
				# resposta da tentiva de cadastro
				my $respostaSalvaDominio = $tree->findnodes( '//body' )->[0]->as_HTML;
				# => alert##T##Dom%EDnio%20cadastrado%20com%20sucesso eval##T##window.location%3D%27%2Fdominio.lista.php%27%3B
				# => alert##T##Este%20dom%EDnio%20j%E1%20est%E1%20em%20nosso%20sistema%20e%20n%E3o%20pode%20ser%20cadastrado%20novamente.
				# ==> %20Favor%2C%20entre%20em%20contato%20com%20nosso%20atendimento%20para%20ver%20a%20situa%E7%E3o%20do%20mesmo.
				
				if(index($respostaSalvaDominio, "cadastrado") != -1 && index($respostaSalvaDominio, "sucesso") != -1)
                        	{
                                    $mech->get("https://painel2.kinghost.net/dominio.lista.php");
                                    $html = $mech->content;
                                    $mech->update_html( $html );
                                    
                                    my $tree = HTML::TreeBuilder::XPath->new;
                                    $tree->parse( $html );
                                    
                                    $table_rows = $tree->findnodes( '//table[@class="default tralt"]/tr' );
                                    
                                    foreach my $row ( $table_rows->get_nodelist )
                                    {
                                        my $tree_tr = HTML::TreeBuilder::XPath->new;
                                        $tree_tr->parse( $row->as_HTML  );
                                        
                                        my $td1 = $tree_tr->findvalue( '//td[1]' );
                                        
                                        my $codigo = $row->as_HTML;
                                        
                                        if(index($td1, $dominio) != -1)
                                        {
                                                my @codigo = split(/redir\(/, $codigo);
                                                @codigo = split(/\)/, $codigo[1]); #"
                                                %resposta = (
                                                        status  => "sucesso",
                                                        resposta =>  "registrado",
                                                        codigo =>  $codigo[0],
                                                        dominio =>  $dominio,
                                                        
                                                 );
                                        }
                                        
                                        $tree_tr->delete;
                                    }
				}
				elsif(index($respostaSalvaDominio, "Este") != -1 && index($respostaSalvaDominio, "nosso") != -1 && index($respostaSalvaDominio, "sistema") != -1)
                        	{
					%resposta = (
						status  => "erro",
						resposta =>  "dominio ja existe",
						dominio =>  $dominio,
					);
				}
				my $json = \%resposta;
				my $json_text = to_json($json);
				return $json_text;
			}
			elsif($mech->status() == 404)
                        {
                             %resposta = (
                                status  => "erro",
                                resposta =>  "not found",
                                url =>  $mech->uri(),
                            );
                            my $json = \%resposta;
                            my $json_text = to_json($json);
                            return $json_text;
                        }
                        else
                        {
                             %resposta = (
                                status  => "erro",
                                resposta =>  "unknow HTTP error",
                                url =>  $mech->uri(),
                            );
                            my $json = \%resposta;
                            my $json_text = to_json($json);
                            return $json_text;
                        }
		}
            }
            else
            {
                %resposta = (
                    status  => "erro",
                    resposta =>  "efetue login primeiro",
                );
                
                my $json = \%resposta;
                my $json_text = to_json($json);
                            
                return $json_text;
            }
        }
        
        
        sub novoPGSql
        {
            my($self, $idDominio, $senha) = @_;
            my %resposta;
            if($statusLogin)
            {
                my $html;
                my $banco;
                # cria pgsql
		$mech->post("https://painel2.kinghost.net/site.pgsql.php?id_dominio=$idDominio");
		if($mech->success())
		{
			if($mech->status() == 200)
			{
				$html = $mech->content;
				$mech->update_html( $html );
				my $tree = HTML::TreeBuilder::XPath->new;
				$tree->parse( $html );
				my $inputValueNBanco = $tree->findnodes( '//input[@id="usuario"]' )->[0]->as_HTML;
				my @nomeBanco = split(/value="/, $inputValueNBanco); #"
                                @nomeBanco = split(/"/, $nomeBanco[1]); #"			
				$banco = $nomeBanco[0];
				$mech->submit_form(
					form_id => "add",
					fields      => {
						control => "pgsql",
						action => "add",
						id_dominio => "$idDominio",
						usuario => $banco,
						db => $banco,
						senha => "$senha",
						csenha => "$senha",
						'charset' => "UTF8",						
					}
				);
				if($mech->success())
				{
					if($mech->status() == 200)
					{
						$html = $mech->content;
						$mech->update_html( $html );
						my $tree = HTML::TreeBuilder::XPath->new;
						$tree->parse( $html );
						%resposta = (
							status  => "sucesso",
							resposta =>  "banco criado",
							banco =>  $banco,
						);
						my $json = \%resposta;
                                                my $json_text = to_json($json);
                                                return $json_text;
					}
					elsif($mech->status() == 404)
                                        {
                                             %resposta = (
                                                status  => "erro",
                                                resposta =>  "not found",
                                                url =>  $mech->uri(),
                                            );
                                            my $json = \%resposta;
                                            my $json_text = to_json($json);
                                            return $json_text;
                                        }
                                        else
                                        {
                                             %resposta = (
                                                status  => "erro",
                                                resposta =>  "unknow HTTP error",
                                                url =>  $mech->uri(),
                                            );
                                            my $json = \%resposta;
                                            my $json_text = to_json($json);
                                            return $json_text;
                                        }
				}
			}
			elsif($mech->status() == 404)
                        {
                             %resposta = (
                                status  => "erro",
                                resposta =>  "not found",
                                url =>  $mech->uri(),
                            );
                            my $json = \%resposta;
                            my $json_text = to_json($json);
                            return $json_text;
                        }
                        else
                        {
                             %resposta = (
                                status  => "erro",
                                resposta =>  "unknow HTTP error",
                                url =>  $mech->uri(),
                            );
                            my $json = \%resposta;
                            my $json_text = to_json($json);
                            return $json_text;
                        }
		}
		# cria pgsql
            }
            else
            {
                %resposta = (
                    status  => "erro",
                    resposta =>  "efetue login primeiro",
                );
                
                my $json = \%resposta;
                my $json_text = to_json($json);
                            
                return $json_text;
            }
        }
1;

__END__
=encoding utf8
 
=head1 NAME

Kinghost::Painel - Object for hosting automation using Kinghost (www.kinghost.net) v2 Control Panel

=head1 VERSION

version 0.001

=head1 SYNOPSIS
  
use Kinghost::Painel; 

my $painel = new Kinghost::Painel();

# Loga no painel
$painel->logar("email@revenda.com.br", "senhadarevenda");


# Novo Cliente
my $empresa = "João25";
my $nome = "José João25";
my $tipoPessoa = "F"; # F - J - I(ignorar)
my $cpfcnpj = "000.000.000-00"; # CPF ou CNPJ
my $email = 'xxxxxgg@gmail.com';
my $emailcobranca = 'xxxxx@gmail.com';
my $senha = "teste";
my $senhaConfimacao = "teste";
my $telefone = "";
my $fax = "";
my $cep = "";
my $endereco = "";
my $cidade = "";
my $estado = "";
print $painel->novoCliente($empresa, $nome, $tipoPessoa, $cpfcnpj, $email, $emailcobranca, $senha, $senhaConfimacao, $telefone, $fax, $cep, $endereco, $cidade, $estado);


# Novo Domínio
my $plano = "45198";
my $dominio = "topjeca.com.br";
my $cliente = "107645";
my $pagoate = "2012-03-01";
my $senha = "testeteste";
my $plataforma = "Windows";
my $webmail = "SquirrelMail";
print $painel->novoDominio($plano, $cliente, $pagoate, $dominio, $senha, $plataforma, $webmail);


# Novo Banco PGSql
my $idDominio = "291076";
my $senha = "teste";
print $painel->novoPGSql($idDominio, $senha);

=head1 METHODS

=head2 logar

Loga no painel de controle. Este método deverá ser usado chamado antes de qualquer outro método. Ativa flag $statusLogin.
$painel->logar($email, $senha);

Return string
logged, invalid login, not found, unknow HTTP error, connection error

=head2 novoCliente

Cadastra novo cliente
print $painel->novoCliente($empresa, $nome, $tipoPessoa, $cpfcnpj, $email, $emailcobranca, $senha, $senhaConfimacao, $telefone, $fax, $cep, $endereco, $cidade, $estado);

Return JSON
{"nome":"José João25","resposta":"registrado","status":"sucesso","codigo":"107630"}
{"resposta":"E-mail em uso","status":"erro"}
{"resposta":"efetue login primeiro","status":"erro"}

=head2 novoDominio

Cadastra novo Dominio
print $painel->novoDominio($plano, $cliente, $pagoate, $dominio, $senha, $plataforma, $webmail);

Return JSON
{"dominio":"topjeca.com.br","resposta":"registrado","status":"sucesso","codigo":"291076"}
{"dominio":"topjeca.com.br","resposta":"dominio ja existe","status":"erro"}

=head2 novoPGSql

Cadastra Banco PGSql
print $painel->novoPGSql($idDominio, $senha);

Return JSON
{"resposta":"banco criado","status":"sucesso","banco":"topjeca"}
 

=head1 AUTHORS

José Eduardo Perotta de Almeida, C<< eduardo at web2solutions.com.br >>


=head1 LICENSE AND COPYRIGHT

Copyright 2012 José Eduardo Perotta de Almeida.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests through the web interface at
L<http://rt.cpan.org>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT
WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER
PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND,
EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE
SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME
THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH
DAMAGES.

=cut


__END__