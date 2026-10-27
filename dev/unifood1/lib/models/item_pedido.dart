import 'excecoes.dart';
import 'formatacao.dart';
import 'produto.dart';

class ItemPedido {
  static const int quantidadeMaxima = 10;

  final Produto _produto;
  final double _precoUnitario;
  int _quantidade;
  String? _observacao;

  ItemPedido({
    required Produto produto,
    int quantidade = 1,
    String? observacao,
  })  : _produto = produto,
        _precoUnitario = produto.preco,
        _quantidade = _validarQuantidade(quantidade),
        _observacao = _validarObservacao(observacao) {
    if (!produto.disponivel) {
      throw ValidacaoException('"${produto.nome}" está indisponível no momento.');
    }
  }

  static int _validarQuantidade(int quantidade) {
    if (quantidade < 1 || quantidade > quantidadeMaxima) {
      throw const ValidacaoException(
          'A quantidade deve estar entre 1 e $quantidadeMaxima por item.');
    }
    return quantidade;
  }

  static String? _validarObservacao(String? observacao) {
    final limpa = observacao?.trim();
    if (limpa == null || limpa.isEmpty) return null;
    if (limpa.length > 100) {
      throw const ValidacaoException(
          'A observação deve ter no máximo 100 caracteres.');
    }
    return limpa;
  }

  Produto get produto => _produto;
  double get precoUnitario => _precoUnitario;

  int get quantidade => _quantidade;
  set quantidade(int valor) => _quantidade = _validarQuantidade(valor);

  String? get observacao => _observacao;
  set observacao(String? valor) => _observacao = _validarObservacao(valor);

  double get subtotal => arredondarCentavos(_precoUnitario * _quantidade);

  @override
  String toString() {
    final obs = _observacao == null ? '' : ' (obs: $_observacao)';
    return '${_quantidade}x ${_produto.nome} - ${formatarReais(subtotal)}$obs';
  }
}
