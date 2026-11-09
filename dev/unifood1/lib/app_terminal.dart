// versao do unifood pelo terminal (enquanto as telas do flutter nao ficam prontas)
// rodar com: dart run lib/app_terminal.dart

import 'dart:io';

import 'banco/banco.dart';
import 'banco/usuarios.dart';
import 'models/excecoes.dart';
import 'models/formatacao.dart';
import 'models/pedido.dart';

String perguntar(String texto) {
  stdout.write(texto);
  return stdin.readLineSync() ?? '';
}

// pergunta a senha sem mostrar o que ta digitando (se o terminal deixar)
String perguntarSenha(String texto) {
  stdout.write(texto);
  var escondeu = false;
  try {
    stdin.echoMode = false;
    escondeu = true;
  } catch (e) {
    // alguns terminais (tipo o do vscode as vezes) nao deixam esconder
  }
  var senha = stdin.readLineSync() ?? '';
  if (escondeu) {
    stdin.echoMode = true;
    print('');
  }
  return senha;
}

void linha() => print('----------------------------------------');

Future<void> main() async {
  print('========================================');
  print('               UNIFOOD');
  print('========================================');

  try {
    await conectar();
  } catch (e) {
    print('Nao foi possivel conectar no banco: $e');
    print('Confira os dados em lib/banco/config.dart');
    return;
  }

  var rodando = true;
  while (rodando) {
    if (usuarioLogado == null) {
      rodando = await menuInicial();
    } else {
      await menuLogado();
    }
  }

  await desconectar();
  print('Ate mais!');
}

// ---------------- MENU SEM LOGIN ----------------

Future<bool> menuInicial() async {
  linha();
  print('1 - Criar conta');
  print('2 - Entrar');
  print('0 - Fechar');
  var opcao = perguntar('Escolha: ').trim();

  if (opcao == '1') {
    await telaCadastro();
  } else if (opcao == '2') {
    await telaLogin();
  } else if (opcao == '0') {
    return false;
  } else {
    print('Opcao invalida.');
  }
  return true;
}

Future<void> telaCadastro() async {
  linha();
  print('CRIAR CONTA');
  var nome = perguntar('Nome completo: ');
  var email = perguntar('E-mail: ');
  var ra = perguntar('RA: ');
  var senha = perguntarSenha('Senha (minimo 8 caracteres): ');
  var senha2 = perguntarSenha('Repita a senha: ');

  if (senha != senha2) {
    print('As senhas nao sao iguais. Tente de novo.');
    return;
  }

  print('\nPara usar o Unifood voce precisa aceitar os Termos de Uso e a Politica de Privacidade.');
  var aceite = perguntar('Aceita? (s/n): ').trim().toLowerCase();

  try {
    var usuario = await cadastrar(
      nome: nome,
      email: email,
      ra: ra,
      senha: senha,
      aceitouTermos: aceite == 's' || aceite == 'sim',
    );
    print('\nConta criada! Bem-vindo(a), ${usuario.primeiroNome}.');
    print('Agora e so entrar com seu RA, e-mail e senha.');
  } on ValidacaoException catch (e) {
    print('\nNao deu pra criar a conta: ${e.mensagem}');
  } catch (e) {
    print('\nErro inesperado: $e');
  }
}

Future<void> telaLogin() async {
  linha();
  print('ENTRAR');
  var ra = perguntar('RA: ');
  var email = perguntar('E-mail: ');
  var senha = perguntarSenha('Senha: ');

  try {
    var usuario = await entrar(ra: ra, email: email, senha: senha);
    print('\nOla, ${usuario.primeiroNome}!');
    if (usuario.status == 'pending_verification') {
      print('(sua conta ainda esta aguardando verificacao do vinculo com a faculdade)');
    }
  } on ValidacaoException catch (e) {
    print('\n${e.mensagem}');
  } catch (e) {
    print('\nErro inesperado: $e');
  }
}

// ---------------- MENU COM LOGIN ----------------

Future<void> menuLogado() async {
  var usuario = usuarioLogado!;
  linha();
  print('Logado como: ${usuario.nome}');
  print('1 - Ver lojas e cardapios');
  print('2 - Fazer pedido');
  print('3 - Meus dados');
  print('0 - Sair da conta');
  var opcao = perguntar('Escolha: ').trim();

  try {
    if (opcao == '1') {
      await telaLojas();
    } else if (opcao == '2') {
      await telaPedido();
    } else if (opcao == '3') {
      telaMeusDados();
    } else if (opcao == '0') {
      await sair();
      print('Voce saiu da conta.');
    } else {
      print('Opcao invalida.');
    }
  } on ValidacaoException catch (e) {
    print('\n${e.mensagem}');
  } catch (e) {
    print('\nErro inesperado: $e');
  }
}

void telaMeusDados() {
  var u = usuarioLogado!;
  linha();
  print('MEUS DADOS');
  print('Nome:   ${u.nome}');
  print('E-mail: ${u.email}');
  print('RA:     ${u.ra}');
  print('Conta:  ${u.statusDescricao ?? u.status}');
  if (u.ultimoLogin != null) {
    print('Ultimo acesso antes deste: ${u.ultimoLogin!.toLocal()}');
  }
}

Future<void> telaLojas() async {
  var lojas = await buscarEstabelecimentos();
  linha();
  for (var loja in lojas) {
    print('\n${loja.nome} - ${loja.local.descricao} ${loja.aberto ? '' : '(fechada)'}');
    var produtos = await buscarProdutos(loja);
    for (var p in produtos) {
      print('   ${p.nome.padRight(32)} ${p.precoFormatado}');
    }
  }
}

Future<void> telaPedido() async {
  var lojas = await buscarEstabelecimentos();
  linha();
  print('ESCOLHA A LOJA');
  for (var i = 0; i < lojas.length; i++) {
    print('${i + 1} - ${lojas[i]}');
  }
  var n = int.tryParse(perguntar('Numero da loja: ').trim());
  if (n == null || n < 1 || n > lojas.length) {
    print('Loja invalida.');
    return;
  }
  var loja = lojas[n - 1];
  var produtos = await buscarProdutos(loja);
  var pedido = Pedido(nomeCliente: usuarioLogado!.nome, estabelecimento: loja);

  // vai adicionando itens ate a pessoa digitar 0
  while (true) {
    linha();
    print('CARDAPIO - ${loja.nome}');
    for (var i = 0; i < produtos.length; i++) {
      print('${(i + 1).toString().padLeft(2)} - ${produtos[i].nome.padRight(32)} ${produtos[i].precoFormatado}');
    }
    if (pedido.itens.isNotEmpty) {
      print('\nNo carrinho: ${pedido.totalUnidades} item(ns) - ${formatarReais(pedido.subtotal)}');
    }
    var escolha = int.tryParse(perguntar('\nNumero do produto (0 para fechar o pedido): ').trim());
    if (escolha == null) {
      print('Digite um numero.');
      continue;
    }
    if (escolha == 0) break;
    if (escolha < 1 || escolha > produtos.length) {
      print('Produto invalido.');
      continue;
    }
    var qtd = int.tryParse(perguntar('Quantidade: ').trim()) ?? 1;
    var obs = perguntar('Observacao (enter para nenhuma): ');
    try {
      pedido.adicionarItem(produtos[escolha - 1], quantidade: qtd, observacao: obs);
    } on ValidacaoException catch (e) {
      print(e.mensagem);
    }
  }

  if (pedido.itens.isEmpty) {
    print('Pedido cancelado (nenhum item).');
    return;
  }

  var cupom = perguntar('Cupom de desconto (enter para nenhum): ').trim();
  if (cupom.isNotEmpty) {
    try {
      pedido.aplicarCupom(cupom);
      print('Cupom aplicado!');
    } on ValidacaoException catch (e) {
      print(e.mensagem);
    }
  }

  linha();
  print(pedido.gerarResumo());
  var ok = perguntar('\nConfirmar pedido? (s/n): ').trim().toLowerCase();
  if (ok != 's' && ok != 'sim') {
    print('Pedido cancelado.');
    return;
  }

  pedido.confirmar();
  // no banco o pedido guarda so o primeiro nome do cliente
  var salvo = await salvarPedido(pedido, cliente: usuarioLogado!.primeiroNome);
  print('\nPedido #${salvo['numero']} enviado!');
  print('Senha de retirada: ${salvo['senha']}');
  print('Fique de olho no balcao da ${loja.nome}.');
}
