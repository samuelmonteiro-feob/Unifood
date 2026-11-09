import 'excecoes.dart';

// usuario do app (tabela identity.users do banco)
// as regras de validacao aqui sao as mesmas que o banco usa
class Usuario {
  String? id; // uuid do banco
  String _nome;
  String _email;
  String _ra;
  String status; // pending_verification, active, suspended ou anonymized
  String? statusDescricao; // o texto em portugues que vem do banco (common.enum_labels)
  DateTime? ultimoLogin;

  Usuario({
    required String nome,
    required String email,
    required String ra,
    this.status = 'pending_verification',
  })  : _nome = validarNome(nome),
        _email = validarEmail(email),
        _ra = validarRa(ra);

  // banco: ck_users_full_name -> length(btrim(full_name)) >= 2
  static String validarNome(String nome) {
    var limpo = nome.trim();
    if (limpo.length < 2) {
      throw const ValidacaoException('O nome deve ter pelo menos 2 caracteres.');
    }
    if (limpo.length > 120) {
      throw const ValidacaoException('O nome pode ter no maximo 120 caracteres.');
    }
    return limpo;
  }

  // o email nao tem um padrao da faculdade, entao so confere o formato basico
  // (o mesmo do dominio common.email_address do banco: algo@algo.algo, ate 254 letras)
  static String validarEmail(String email) {
    var limpo = email.trim().toLowerCase();
    var formato = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!formato.hasMatch(limpo) || limpo.length > 254) {
      throw const ValidacaoException('E-mail invalido. Exemplo: nome@email.com');
    }
    return limpo;
  }

  // RA: por enquanto NAO valida o formato (o banco ainda nao tem os RAs dos alunos)
  // as regras do RA estao anotadas em docs/ORIENTACOES.md pra fazer depois
  static String validarRa(String ra) {
    var limpo = ra.trim();
    if (limpo.isEmpty) {
      throw const ValidacaoException('Informe o RA.');
    }
    return limpo;
  }

  static String validarSenha(String senha) {
    if (senha.length < 8) {
      throw const ValidacaoException('A senha precisa ter pelo menos 8 caracteres.');
    }
    if (senha.length > 128) {
      throw const ValidacaoException('A senha pode ter no maximo 128 caracteres.');
    }
    return senha;
  }

  String get nome => _nome;
  set nome(String valor) => _nome = validarNome(valor);

  String get email => _email;
  String get ra => _ra;

  // primeiro nome, usado nos pedidos (o banco so mostra o primeiro nome do cliente)
  String get primeiroNome => _nome.split(' ').first;

  bool get podeEntrar => status == 'pending_verification' || status == 'active';

  @override
  String toString() => '$_nome (RA $_ra) - $_email';
}
