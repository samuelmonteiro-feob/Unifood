import 'package:postgres/postgres.dart';

import '../models/estabelecimento.dart';
import '../models/pedido.dart';
import '../models/produto.dart';
import 'config.dart'; // host, porta, usuario e senha ficam nesse arquivo (ver config_exemplo.dart)

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

// ---------------- ESTABELECIMENTOS ----------------

Future<List<Estabelecimento>> buscarEstabelecimentos() async {
  var conn = await conectar();
  var resultado = await conn.execute(
      'SELECT id, nome, local, capacidade, aberto FROM estabelecimentos ORDER BY id');

  List<Estabelecimento> lista = [];
  for (var linha in resultado) {
    var e = Estabelecimento(
      nome: linha[1] as String,
      local: LocalAlimentacao.values.byName(linha[2] as String),
      capacidadeSimultanea: linha[3] as int,
      aberto: linha[4] as bool,
    );
    e.id = linha[0] as int;
    lista.add(e);
  }
  return lista;
}

// busca os produtos do estabelecimento e ja coloca dentro dele
Future<List<Produto>> buscarProdutos(Estabelecimento estabelecimento) async {
  var conn = await conectar();
  var resultado = await conn.execute(
    Sql.named(
        'SELECT id, nome, preco::float8, tempo_preparo, disponivel FROM produtos WHERE estabelecimento_id = @id ORDER BY nome'),
    parameters: {'id': estabelecimento.id},
  );

  List<Produto> lista = [];
  for (var linha in resultado) {
    var p = Produto(
      nome: linha[1] as String,
      preco: linha[2] as double,
      tempoPreparoMin: linha[3] as int,
      disponivel: linha[4] as bool,
    );
    p.id = linha[0] as int;
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
  if (produto.id == null) {
    var resultado = await conn.execute(
      Sql.named(
          'INSERT INTO produtos (estabelecimento_id, nome, preco, tempo_preparo, disponivel) VALUES (@est, @nome, @preco, @tempo, @disp) RETURNING id'),
      parameters: {
        'est': estabelecimento.id,
        'nome': produto.nome,
        'preco': produto.preco,
        'tempo': produto.tempoPreparoMin,
        'disp': produto.disponivel,
      },
    );
    produto.id = resultado[0][0] as int;
  } else {
    await conn.execute(
      Sql.named(
          'UPDATE produtos SET nome = @nome, preco = @preco, tempo_preparo = @tempo, disponivel = @disp WHERE id = @id'),
      parameters: {
        'id': produto.id,
        'nome': produto.nome,
        'preco': produto.preco,
        'tempo': produto.tempoPreparoMin,
        'disp': produto.disponivel,
      },
    );
  }
}

Future<void> atualizarAberto(Estabelecimento estabelecimento) async {
  var conn = await conectar();
  await conn.execute(
    Sql.named('UPDATE estabelecimentos SET aberto = @aberto WHERE id = @id'),
    parameters: {'aberto': estabelecimento.aberto, 'id': estabelecimento.id},
  );
}

// ---------------- PEDIDOS ----------------

// salva o pedido e os itens, retorna o id que o banco gerou
Future<int> salvarPedido(Pedido pedido) async {
  var conn = await conectar();
  int idPedido = 0;

  // usa transacao pra nao salvar pedido sem item se der erro no meio
  await conn.runTx((tx) async {
    var resultado = await tx.execute(
      Sql.named(
          'INSERT INTO pedidos (estabelecimento_id, nome_cliente, status, cupom, total, horario_retirada) VALUES (@est, @cliente, @status, @cupom, @total, @horario) RETURNING id'),
      parameters: {
        'est': pedido.estabelecimento.id,
        'cliente': pedido.nomeCliente,
        'status': pedido.status.name,
        'cupom': pedido.cupomAplicado,
        'total': pedido.total,
        'horario': pedido.horarioRetirada,
      },
    );
    idPedido = resultado[0][0] as int;

    for (var item in pedido.itens) {
      await tx.execute(
        Sql.named(
            'INSERT INTO itens_pedido (pedido_id, produto_id, quantidade, preco_unitario, observacao) VALUES (@pedido, @produto, @qtd, @preco, @obs)'),
        parameters: {
          'pedido': idPedido,
          'produto': item.produto.id,
          'qtd': item.quantidade,
          'preco': item.precoUnitario,
          'obs': item.observacao,
        },
      );
    }
  });

  return idPedido;
}

Future<void> atualizarStatusPedido(int idPedido, StatusPedido status) async {
  var conn = await conectar();
  await conn.execute(
    Sql.named('UPDATE pedidos SET status = @status WHERE id = @id'),
    parameters: {'status': status.name, 'id': idPedido},
  );
}

// lista os pedidos (volta como map pq e so pra mostrar na tela)
Future<List<Map<String, dynamic>>> buscarPedidos({int? idEstabelecimento}) async {
  var conn = await conectar();
  var sql = 'SELECT p.id, p.nome_cliente, p.status, p.total::float8, p.criado_em, e.nome '
      'FROM pedidos p JOIN estabelecimentos e ON e.id = p.estabelecimento_id';
  Map<String, dynamic> parametros = {};
  if (idEstabelecimento != null) {
    sql += ' WHERE p.estabelecimento_id = @est';
    parametros['est'] = idEstabelecimento;
  }
  sql += ' ORDER BY p.id DESC';

  var resultado = await conn.execute(Sql.named(sql), parameters: parametros);

  List<Map<String, dynamic>> lista = [];
  for (var linha in resultado) {
    lista.add({
      'id': linha[0],
      'cliente': linha[1],
      'status': StatusPedido.values.byName(linha[2] as String),
      'total': linha[3],
      'criado_em': linha[4],
      'estabelecimento': linha[5],
    });
  }
  return lista;
}

Future<List<Map<String, dynamic>>> buscarItensDoPedido(int idPedido) async {
  var conn = await conectar();
  var resultado = await conn.execute(
    Sql.named(
        'SELECT pr.nome, i.quantidade, i.preco_unitario::float8, i.observacao FROM itens_pedido i JOIN produtos pr ON pr.id = i.produto_id WHERE i.pedido_id = @id'),
    parameters: {'id': idPedido},
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
