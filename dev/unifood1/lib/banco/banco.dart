import 'dart:math';

import 'package:postgres/postgres.dart';

import '../models/estabelecimento.dart';
import '../models/pedido.dart';
import '../models/produto.dart';
import 'config.dart'; // host, porta, usuario e senha ficam nesse arquivo (ver config_exemplo.dart)

// as tabelas que a gente usa ficam no schema negocio_teste do banco do unifood
// (lojas, produtos, pedidos, itens_pedido, fila_retirada...)

Connection? conexao;

Future<Connection> conectar() async {
  // se ja ta conectado usa a mesma conexao
  if (conexao != null && conexao!.isOpen) {
    return conexao!;
  }
  conexao = await Connection.open(
    Endpoint(
      host: host,
      port: porta,
      database: nomeBanco,
      username: usuario,
      password: senha,
    ),
    settings: ConnectionSettings(sslMode: SslMode.disable),
  );
  print('conectou no banco');
  return conexao!;
}

Future<void> desconectar() async {
  if (conexao != null) {
    await conexao!.close();
    conexao = null;
  }
}

// no banco o status ta escrito em_preparo e no dart e emPreparo, entao precisa converter
String statusParaBanco(StatusPedido status) {
  if (status == StatusPedido.emPreparo) {
    return 'em_preparo';
  }
  return status.name;
}

StatusPedido statusDoBanco(String texto) {
  if (texto == 'em_preparo') {
    return StatusPedido.emPreparo;
  }
  return StatusPedido.values.byName(texto);
}

// procura o local pelo texto que ta no banco (ex: "Praça de Alimentação 1")
LocalAlimentacao localDoBanco(String texto) {
  for (var local in LocalAlimentacao.values) {
    if (local.descricao == texto) {
      return local;
    }
  }
  print('local nao encontrado: $texto, usando praca 1');
  return LocalAlimentacao.praca1;
}

// gera a senha de retirada tipo "3ED689"
String gerarSenha() {
  var letras = '0123456789ABCDEF';
  var r = Random();
  var senha = '';
  for (var i = 0; i < 6; i++) {
    senha += letras[r.nextInt(letras.length)];
  }
  return senha;
}

// ---------------- LOJAS (ESTABELECIMENTOS) ----------------

Future<List<Estabelecimento>> buscarEstabelecimentos() async {
  var conn = await conectar();
  var resultado = await conn.execute(
      'SELECT id::text, slug, nome, local_no_campus, situacao, aceitando_pedidos '
      'FROM negocio_teste.lojas ORDER BY nome');

  List<Estabelecimento> lista = [];
  for (var linha in resultado) {
    // so ta aberto se a loja ta ativa e aceitando pedido
    var aberto = linha[4] == 'ativa' && linha[5] == true;
    var e = Estabelecimento(
      nome: linha[2] as String,
      local: localDoBanco(linha[3] as String),
      aberto: aberto,
    );
    e.id = linha[0] as String;
    e.slug = linha[1] as String;
    lista.add(e);
  }
  return lista;
}

// busca os produtos da loja e ja coloca dentro do estabelecimento
Future<List<Produto>> buscarProdutos(Estabelecimento estabelecimento) async {
  var conn = await conectar();
  // o banco nao tem tempo de preparo por produto, entao usa o tempo minimo da loja
  var resultado = await conn.execute(
    Sql.named('SELECT p.id::text, p.nome, p.preco::float8, l.preparo_min_minutos, p.situacao '
        'FROM negocio_teste.produtos p JOIN negocio_teste.lojas l ON l.slug = p.loja '
        'WHERE p.loja = @loja ORDER BY p.secao, p.nome'),
    parameters: {'loja': estabelecimento.slug},
  );

  List<Produto> lista = [];
  for (var linha in resultado) {
    var p = Produto(
      nome: linha[1] as String,
      preco: linha[2] as double,
      tempoPreparoMin: linha[3] as int,
      disponivel: linha[4] == 'ativo',
    );
    p.id = linha[0] as String;
    lista.add(p);

    // coloca no estabelecimento se ainda nao tiver
    try {
      estabelecimento.adicionarProduto(p);
    } catch (e) {
      // ja tinha, ignora
    }
  }
  return lista;
}

Future<void> salvarProduto(Estabelecimento estabelecimento, Produto produto) async {
  var conn = await conectar();
  var situacao = produto.disponivel ? 'ativo' : 'inativo';
  if (produto.id == null) {
    var resultado = await conn.execute(
      Sql.named('INSERT INTO negocio_teste.produtos '
          '(id, loja, nome, preco, preco_original, situacao, controla_estoque, restrito_maiores_18, criado_em) '
          'VALUES (gen_random_uuid(), @loja, @nome, @preco, @preco, @situacao, false, false, now()) '
          'RETURNING id::text'),
      parameters: {
        'loja': estabelecimento.slug,
        'nome': produto.nome,
        'preco': produto.preco,
        'situacao': situacao,
      },
    );
    produto.id = resultado[0][0] as String;
  } else {
    await conn.execute(
      Sql.named('UPDATE negocio_teste.produtos SET nome = @nome, preco = @preco, situacao = @situacao '
          'WHERE id = @id::uuid'),
      parameters: {
        'id': produto.id,
        'nome': produto.nome,
        'preco': produto.preco,
        'situacao': situacao,
      },
    );
  }
}

Future<void> atualizarAberto(Estabelecimento estabelecimento) async {
  var conn = await conectar();
  await conn.execute(
    Sql.named('UPDATE negocio_teste.lojas SET aceitando_pedidos = @aberto WHERE slug = @loja'),
    parameters: {'aberto': estabelecimento.aberto, 'loja': estabelecimento.slug},
  );
}

// ---------------- PEDIDOS ----------------

// salva o pedido, os itens e coloca na fila de retirada
// retorna o numero do pedido (ex: 101813)
Future<int> salvarPedido(Pedido pedido, {String? cliente}) async {
  var conn = await conectar();
  int numero = 0;
  var senhaRetirada = gerarSenha();
  var loja = pedido.estabelecimento.slug;
  // no banco os clientes sao tipo "cliente_003", se nao passar usa o nome do pedido
  var nomeCliente = cliente ?? pedido.nomeCliente;

  // usa transacao pra nao salvar pedido sem item se der erro no meio
  await conn.runTx((tx) async {
    // pega o proximo numero de pedido
    var r = await tx.execute('SELECT coalesce(max(numero), 100000) + 1 FROM negocio_teste.pedidos');
    numero = r[0][0] as int;

    await tx.execute(
      Sql.named('INSERT INTO negocio_teste.pedidos '
          '(id, numero, data_pedido, loja, cliente, situacao, senha_retirada, retirada_agendada_para, '
          'subtotal, desconto, taxa_servico, total, confirmado_em) '
          'VALUES (gen_random_uuid(), @numero, now(), @loja, @cliente, @situacao, @senha, @horario, '
          '@subtotal, @desconto, 0, @total, now())'),
      parameters: {
        'numero': numero,
        'loja': loja,
        'cliente': nomeCliente,
        'situacao': statusParaBanco(pedido.status),
        'senha': senhaRetirada,
        'horario': pedido.horarioRetirada,
        'subtotal': pedido.subtotal,
        'desconto': pedido.valorDesconto,
        'total': pedido.total,
      },
    );

    for (var item in pedido.itens) {
      await tx.execute(
        Sql.named('INSERT INTO negocio_teste.itens_pedido '
            '(id, numero_pedido, loja, produto, quantidade, preco_unitario, complementos_por_unidade, total_item, observacao) '
            'VALUES (gen_random_uuid(), @numero, @loja, @produto, @qtd, @preco, 0, @total, @obs)'),
        parameters: {
          'numero': numero,
          'loja': loja,
          'produto': item.produto.nome,
          'qtd': item.quantidade,
          'preco': item.precoUnitario,
          'total': item.subtotal,
          'obs': item.observacao,
        },
      );
    }

    // coloca no fim da fila da loja
    var f = await tx.execute(
      Sql.named('SELECT count(*) FROM negocio_teste.fila_retirada WHERE loja = @loja'),
      parameters: {'loja': loja},
    );
    var posicao = (f[0][0] as int) + 1;
    await tx.execute(
      Sql.named('INSERT INTO negocio_teste.fila_retirada '
          '(numero_pedido, loja, senha, cliente, situacao, posicao_na_fila, previsao_de_pronto) '
          'VALUES (@numero, @loja, @senha, @cliente, @situacao, @posicao, now() + make_interval(mins => @min))'),
      parameters: {
        'numero': numero,
        'loja': loja,
        'senha': senhaRetirada,
        'cliente': nomeCliente,
        'situacao': statusParaBanco(pedido.status),
        'posicao': posicao,
        'min': pedido.tempoEsperaEstimado,
      },
    );
  });

  return numero;
}

Future<void> atualizarStatusPedido(int numero, StatusPedido status) async {
  var conn = await conectar();
  var situacao = statusParaBanco(status);

  // atualiza tambem o horario de cada etapa
  var coluna = '';
  if (status == StatusPedido.pronto) coluna = ', pronto_em = now()';
  if (status == StatusPedido.retirado) coluna = ', retirado_em = now()';
  if (status == StatusPedido.cancelado) coluna = ', cancelado_em = now()';

  await conn.execute(
    Sql.named('UPDATE negocio_teste.pedidos SET situacao = @situacao$coluna WHERE numero = @numero'),
    parameters: {'situacao': situacao, 'numero': numero},
  );

  // se ja retirou ou cancelou sai da fila, se nao so atualiza
  if (status == StatusPedido.retirado || status == StatusPedido.cancelado) {
    await conn.execute(
      Sql.named('DELETE FROM negocio_teste.fila_retirada WHERE numero_pedido = @numero'),
      parameters: {'numero': numero},
    );
  } else {
    await conn.execute(
      Sql.named('UPDATE negocio_teste.fila_retirada SET situacao = @situacao WHERE numero_pedido = @numero'),
      parameters: {'situacao': situacao, 'numero': numero},
    );
  }
}

// lista os ultimos pedidos (volta como map pq e so pra mostrar na tela)
// tem quase 2 mil pedidos no banco entao limita
Future<List<Map<String, dynamic>>> buscarPedidos({String? loja, int limite = 20}) async {
  var conn = await conectar();
  var sql = 'SELECT p.numero, p.cliente, p.situacao, p.total::float8, p.data_pedido, l.nome, p.senha_retirada '
      'FROM negocio_teste.pedidos p JOIN negocio_teste.lojas l ON l.slug = p.loja';
  Map<String, dynamic> parametros = {'limite': limite};
  if (loja != null) {
    sql += ' WHERE p.loja = @loja';
    parametros['loja'] = loja;
  }
  sql += ' ORDER BY p.numero DESC LIMIT @limite';

  var resultado = await conn.execute(Sql.named(sql), parameters: parametros);

  List<Map<String, dynamic>> lista = [];
  for (var linha in resultado) {
    lista.add({
      'numero': linha[0],
      'cliente': linha[1],
      'status': statusDoBanco(linha[2] as String),
      'total': linha[3],
      'data': linha[4],
      'estabelecimento': linha[5],
      'senha': linha[6],
    });
  }
  return lista;
}

Future<List<Map<String, dynamic>>> buscarItensDoPedido(int numero) async {
  var conn = await conectar();
  var resultado = await conn.execute(
    Sql.named('SELECT produto, quantidade, preco_unitario::float8, observacao '
        'FROM negocio_teste.itens_pedido WHERE numero_pedido = @numero'),
    parameters: {'numero': numero},
  );

  List<Map<String, dynamic>> lista = [];
  for (var linha in resultado) {
    lista.add({
      'produto': linha[0],
      'quantidade': linha[1],
      'preco': linha[2],
      'observacao': linha[3],
    });
  }
  return lista;
}

// fila de retirada de uma loja (pedidos que ainda nao foram retirados)
Future<List<Map<String, dynamic>>> buscarFila(String loja) async {
  var conn = await conectar();
  var resultado = await conn.execute(
    Sql.named('SELECT numero_pedido, senha, cliente, situacao, posicao_na_fila '
        'FROM negocio_teste.fila_retirada WHERE loja = @loja ORDER BY posicao_na_fila'),
    parameters: {'loja': loja},
  );

  List<Map<String, dynamic>> lista = [];
  for (var linha in resultado) {
    lista.add({
      'numero': linha[0],
      'senha': linha[1],
      'cliente': linha[2],
      'status': statusDoBanco(linha[3] as String),
      'posicao': linha[4],
    });
  }
  return lista;
}
