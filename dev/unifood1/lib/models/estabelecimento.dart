import 'excecoes.dart';
import 'produto.dart';


enum LocalAlimentacao {
  praca1('Praça de Alimentação 1'),
  praca2PredioD('Praça de Alimentação 2 - Prédio D'),
  praca2PredioE('Praça de Alimentação 2 - Prédio E'),
  predioF('Prédio F');

  final String descricao;
  const LocalAlimentacao(this.descricao);
}


class Estabelecimento {
  int? id; // id do banco
  String _nome;
  final LocalAlimentacao _local;
  final List<Produto> _produtos = [];
  bool _aberto;
  int _capacidadeSimultanea;
  int _pedidosEmPreparo = 0;

  Estabelecimento({
    required String nome,
    required this._local,
    int capacidadeSimultanea = 5,
    this._aberto = true,
  })  : _nome = _validarNome(nome),
        _capacidadeSimultanea = _validarCapacidade(capacidadeSimultanea);

  static String _validarNome(String nome) {
    final limpo = nome.trim();
    if (limpo.length < 2 || limpo.length > 60) {
      throw const ValidacaoException(
          'O nome do estabelecimento deve ter entre 2 e 60 caracteres.');
    }
    return limpo;
  }

  static int _validarCapacidade(int capacidade) {
    if (capacidade < 1 || capacidade > 50) {
      throw const ValidacaoException(
          'A capacidade deve estar entre 1 e 50 pedidos simultâneos.');
    }
    return capacidade;
  }

  String get nome => _nome;
  set nome(String valor) => _nome = _validarNome(valor);

  LocalAlimentacao get local => _local;

  bool get aberto => _aberto;

  int get capacidadeSimultanea => _capacidadeSimultanea;
  set capacidadeSimultanea(int valor) =>
      _capacidadeSimultanea = _validarCapacidade(valor);

  int get pedidosEmPreparo => _pedidosEmPreparo;

  List<Produto> get produtos => List.unmodifiable(_produtos);

  List<Produto> get produtosDisponiveis =>
      _produtos.where((p) => p.disponivel).toList();

  void abrir() => _aberto = true;
  void fechar() => _aberto = false;

  void adicionarProduto(Produto produto) {
    final jaExiste = _produtos
        .any((p) => p.nome.toLowerCase() == produto.nome.toLowerCase());
    if (jaExiste) {
      throw ValidacaoException(
          'Já existe um produto chamado "${produto.nome}" em $_nome.');
    }
    _produtos.add(produto);
  }

  void removerProduto(String nome) {
    final antes = _produtos.length;
    _produtos.removeWhere((p) => p.nome.toLowerCase() == nome.toLowerCase());
    if (_produtos.length == antes) {
      throw ValidacaoException('Produto "$nome" não encontrado em $_nome.');
    }
  }

  double get ocupacaoPercentual => _pedidosEmPreparo / _capacidadeSimultanea * 100;

  String get nivelLotacao {
    if (!_aberto) return 'Fechado';
    if (ocupacaoPercentual < 50) return 'Tranquilo';
    if (ocupacaoPercentual < 100) return 'Movimentado';
    return 'Lotado';
  }

  bool get podeReceberPedidos =>
      _aberto && _pedidosEmPreparo < _capacidadeSimultanea;

  void registrarPedidoEmPreparo() {
    if (!_aberto) {
      throw ValidacaoException('$_nome está fechado no momento.');
    }
    if (_pedidosEmPreparo >= _capacidadeSimultanea) {
      throw ValidacaoException(
          '$_nome atingiu o limite de pedidos simultâneos. Tente novamente em instantes.');
    }
    _pedidosEmPreparo++;
  }

  void liberarPedido() {
    if (_pedidosEmPreparo == 0) {
      throw const ValidacaoException('Não há pedidos em preparo para liberar.');
    }
    _pedidosEmPreparo--;
  }

  int estimarTempoEspera(int tempoPreparoPedidoMin) {
    if (tempoPreparoPedidoMin < 0) {
      throw const ValidacaoException('O tempo de preparo não pode ser negativo.');
    }
    return tempoPreparoPedidoMin + (_pedidosEmPreparo ~/ 2);
  }

  @override
  String toString() => '$_nome (${_local.descricao})';
}
