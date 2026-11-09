import 'excecoes.dart';
import 'formatacao.dart';

class Produto {
  String? id; // id do banco (uuid), fica null se ainda nao salvou
  String _nome;
  double _preco;
  int _tempoPreparoMin;
  bool _disponivel;

  Produto({
    required String nome,
    required double preco,
    int tempoPreparoMin = 5,
    this._disponivel = true,
  })  : _nome = _validarNome(nome),
        _preco = _validarPreco(preco),
        _tempoPreparoMin = _validarTempoPreparo(tempoPreparoMin);


  static String _validarNome(String nome) {
    final limpo = nome.trim();
    if (limpo.length < 2 || limpo.length > 50) {
      throw const ValidacaoException(
          'O nome do produto deve ter entre 2 e 50 caracteres.');
    }
    return limpo;
  }

  static double _validarPreco(double preco) {
    if (preco.isNaN || preco <= 0) {
      throw const ValidacaoException('O preço deve ser maior que zero.');
    }
    if (preco > 500) {
      throw const ValidacaoException('O preço não pode passar de R\$ 500,00.');
    }
    return arredondarCentavos(preco);
  }

  static int _validarTempoPreparo(int minutos) {
    if (minutos < 1 || minutos > 60) {
      throw const ValidacaoException(
          'O tempo de preparo deve estar entre 1 e 60 minutos.');
    }
    return minutos;
  }

  String get nome => _nome;
  set nome(String valor) => _nome = _validarNome(valor);

  double get preco => _preco;
  set preco(double valor) => _preco = _validarPreco(valor);

  int get tempoPreparoMin => _tempoPreparoMin;
  set tempoPreparoMin(int valor) =>
      _tempoPreparoMin = _validarTempoPreparo(valor);

  bool get disponivel => _disponivel;
  set disponivel(bool valor) => _disponivel = valor;

  String get precoFormatado => formatarReais(_preco);

  double calcularPrecoComDesconto(double percentual) {
    if (percentual < 0 || percentual > 100) {
      throw const ValidacaoException(
          'O desconto deve estar entre 0% e 100%.');
    }
    return arredondarCentavos(_preco * (1 - percentual / 100));
  }

  void reajustarPreco(double percentual) {
    if (percentual < -90 || percentual > 100) {
      throw const ValidacaoException(
          'O reajuste deve estar entre -90% e +100%.');
    }
    _preco = _validarPreco(_preco * (1 + percentual / 100));
  }

  @override
  String toString() => '$_nome - $precoFormatado';
}
