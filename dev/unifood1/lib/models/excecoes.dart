class ValidacaoException implements Exception {
  final String mensagem;

  const ValidacaoException(this.mensagem);

  @override
  String toString() => 'ValidacaoException: $mensagem';
}
