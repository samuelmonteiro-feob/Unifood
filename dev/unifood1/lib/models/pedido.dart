import 'estabelecimento.dart';
import 'excecoes.dart';
import 'formatacao.dart';
import 'item_pedido.dart';
import 'produto.dart';

enum StatusPedido {
  rascunho('Rascunho'),
  confirmado('Confirmado'),
  emPreparo('Em preparo'),
  pronto('Pronto para retirada'),
  retirado('Retirado'),
  cancelado('Cancelado');

  final String descricao;
  const StatusPedido(this.descricao);
}
class Pedido {
  static int _proximoId = 1;

  static const Map<String, double> _cupons = {
    'UNIFEOB10': 10,
    'PRIMEIRA5': 5,
  };

  final int _id;
  String _nomeCliente;
  final Estabelecimento _estabelecimento;
  final List<ItemPedido> _itens = [];
  StatusPedido _status = StatusPedido.rascunho;
  String? _cupomAplicado;
  double _percentualDesconto = 0;
  DateTime? _horarioRetirada;
  bool _ocupaVaga = false; 

  Pedido({
    required String nomeCliente,
    required Estabelecimento estabelecimento,
  })  : _nomeCliente = _validarNomeCliente(nomeCliente),
        _estabelecimento = estabelecimento,
        _id = _proximoId++ {
    if (!estabelecimento.aberto) {
      throw ValidacaoException('${estabelecimento.nome} está fechado.');
    }
  }

  static String _validarNomeCliente(String nome) {
    final limpo = nome.trim();
    if (limpo.length < 3 || limpo.length > 60) {
      throw const ValidacaoException(
          'O nome do cliente deve ter entre 3 e 60 caracteres.');
    }
    return limpo;
  }

  int get id => _id;
  Estabelecimento get estabelecimento => _estabelecimento;
  StatusPedido get status => _status;
  String? get cupomAplicado => _cupomAplicado;
  DateTime? get horarioRetirada => _horarioRetirada;

  String get nomeCliente => _nomeCliente;
  set nomeCliente(String valor) {
    _exigirStatus(StatusPedido.rascunho, 'alterar o nome do cliente');
    _nomeCliente = _validarNomeCliente(valor);
  }

  List<ItemPedido> get itens => List.unmodifiable(_itens);

  int get totalUnidades => _itens.fold(0, (soma, item) => soma + item.quantidade);

  double get subtotal =>
      arredondarCentavos(_itens.fold(0.0, (soma, item) => soma + item.subtotal));

  double get valorDesconto =>
      arredondarCentavos(subtotal * _percentualDesconto / 100);

  double get total => arredondarCentavos(subtotal - valorDesconto);

  int get tempoPreparoEstimado {
    if (_itens.isEmpty) return 0;
    final maior = _itens
        .map((i) => i.produto.tempoPreparoMin)
        .reduce((a, b) => a > b ? a : b);
    return maior + (totalUnidades - 1) ~/ 3;
  }

  int get tempoEsperaEstimado =>
      _estabelecimento.estimarTempoEspera(tempoPreparoEstimado);


  void adicionarItem(Produto produto, {int quantidade = 1, String? observacao}) {
    _exigirStatus(StatusPedido.rascunho, 'adicionar itens');
    if (!_estabelecimento.produtos.contains(produto)) {
      throw ValidacaoException(
          '"${produto.nome}" não é vendido por ${_estabelecimento.nome}.');
    }
    if (!produto.disponivel) {
      throw ValidacaoException('"${produto.nome}" está indisponível no momento.');
    }

    final existente = _buscarItem(produto);
    if (existente != null) {

      existente.quantidade = existente.quantidade + quantidade;
      if (observacao != null) existente.observacao = observacao;
      return;
    }
    _itens.add(ItemPedido(
      produto: produto,
      quantidade: quantidade,
      observacao: observacao,
    ));
  }

  void removerItem(String nomeProduto) {
    _exigirStatus(StatusPedido.rascunho, 'remover itens');
    final antes = _itens.length;
    _itens.removeWhere(
        (i) => i.produto.nome.toLowerCase() == nomeProduto.toLowerCase());
    if (_itens.length == antes) {
      throw ValidacaoException('"$nomeProduto" não está no pedido.');
    }
  }

  void aplicarCupom(String codigo) {
    _exigirStatus(StatusPedido.rascunho, 'aplicar cupom');
    final chave = codigo.trim().toUpperCase();
    final percentual = _cupons[chave];
    if (percentual == null) {
      throw ValidacaoException('Cupom "$codigo" inválido.');
    }
    _cupomAplicado = chave;
    _percentualDesconto = percentual;
  }

  void agendarRetirada(DateTime horario) {
    _exigirStatus(StatusPedido.rascunho, 'agendar a retirada');
    if (_itens.isEmpty) {
      throw const ValidacaoException(
          'Adicione itens antes de agendar a retirada.');
    }
    final agora = DateTime.now();
    final minimo = agora.add(Duration(minutes: tempoEsperaEstimado));
    if (horario.isBefore(minimo)) {
      throw ValidacaoException(
          'O horário é cedo demais. O pedido leva cerca de $tempoEsperaEstimado min.');
    }
    if (horario.isAfter(agora.add(const Duration(hours: 4)))) {
      throw const ValidacaoException(
          'A retirada só pode ser agendada para as próximas 4 horas.');
    }
    _horarioRetirada = horario;
  }

  void confirmar() {
    _exigirStatus(StatusPedido.rascunho, 'confirmar o pedido');
    if (_itens.isEmpty) {
      throw const ValidacaoException('O pedido não tem nenhum item.');
    }
    _estabelecimento.registrarPedidoEmPreparo();
    _ocupaVaga = true;
    _status = StatusPedido.confirmado;
  }

  void avancarStatus() {
    switch (_status) {
      case StatusPedido.rascunho:
        throw const ValidacaoException(
            'Use confirmar() para enviar o pedido ao estabelecimento.');
      case StatusPedido.confirmado:
        _status = StatusPedido.emPreparo;
        break;
      case StatusPedido.emPreparo:
        _status = StatusPedido.pronto;
        _liberarVaga();
        break;
      case StatusPedido.pronto:
        _status = StatusPedido.retirado;
        break;
      case StatusPedido.retirado:
      case StatusPedido.cancelado:
        throw ValidacaoException(
            'O pedido já está "${_status.descricao}" e não pode avançar.');
    }
  }

  void cancelar() {
    if (_status != StatusPedido.rascunho && _status != StatusPedido.confirmado) {
      throw ValidacaoException(
          'Não é possível cancelar um pedido "${_status.descricao}".');
    }
    _liberarVaga();
    _status = StatusPedido.cancelado;
  }

  String gerarResumo() {
    final b = StringBuffer()
      ..writeln('Pedido #$_id - $_nomeCliente')
      ..writeln('Local: $_estabelecimento')
      ..writeln('Status: ${_status.descricao}');
    for (final item in _itens) {
      b.writeln('  - $item');
    }
    b.writeln('Subtotal: ${formatarReais(subtotal)}');
    if (_cupomAplicado != null) {
      b.writeln('Desconto ($_cupomAplicado): -${formatarReais(valorDesconto)}');
    }
    b.writeln('Total: ${formatarReais(total)}');
    b.write('Tempo estimado: $tempoEsperaEstimado min');
    return b.toString();
  }

  ItemPedido? _buscarItem(Produto produto) {
    for (final item in _itens) {
      if (identical(item.produto, produto)) return item;
    }
    return null;
  }

  void _exigirStatus(StatusPedido esperado, String acao) {
    if (_status != esperado) {
      throw ValidacaoException(
          'Não é possível $acao com o pedido "${_status.descricao}".');
    }
  }

  void _liberarVaga() {
    if (_ocupaVaga) {
      _estabelecimento.liberarPedido();
      _ocupaVaga = false;
    }
  }
}
