import 'package:postgres/postgres.dart';

import '../models/excecoes.dart';
import '../models/usuario.dart';
import 'banco.dart';
import 'senha.dart';

// cadastro e login usando as tabelas reais do schema identity:
//   identity.users           -> dados da pessoa (nome, email, ra, status)
//   identity.auth_identities -> hash da senha (provider = 'password')
//   identity.user_consents   -> aceite dos termos de uso e politica de privacidade
//   identity.sessions        -> sessao aberta quando faz login

// quem ta logado agora (null = ninguem)
Usuario? usuarioLogado;
String? idSessao;

// ---------------- CADASTRO ----------------

Future<Usuario> cadastrar({
  required String nome,
  required String email,
  required String ra,
  required String senha,
  required bool aceitouTermos,
}) async {
  // valida tudo antes de ir no banco
  var usuario = Usuario(nome: nome, email: email, ra: ra);
  Usuario.validarSenha(senha);
  if (!aceitouTermos) {
    throw const ValidacaoException('Para criar a conta e preciso aceitar os termos de uso e a politica de privacidade.');
  }

  var hash = await gerarHashSenha(senha);
  var conn = await conectar();

  try {
    await conn.runTx((tx) async {
      // o banco nao tem regra de RA unico ainda, entao confere aqui pra nao ter 2 contas com o mesmo RA
      var jaTem = await tx.execute(
        Sql.named('SELECT 1 FROM identity.users WHERE ra = @ra AND deleted_at IS NULL'),
        parameters: {'ra': usuario.ra},
      );
      if (jaTem.isNotEmpty) {
        throw const ValidacaoException('Ja existe uma conta com esse RA.');
      }

      var r = await tx.execute(
        Sql.named('INSERT INTO identity.users (email, full_name, ra) '
            'VALUES (CAST(@email AS public.citext), @nome, @ra) '
            'RETURNING id::text, status::text'),
        parameters: {'email': usuario.email, 'nome': usuario.nome, 'ra': usuario.ra},
      );
      usuario.id = r[0][0] as String;
      usuario.status = r[0][1] as String;

      // senha: provider_subject e o email em minusculo (comentario da coluna no banco)
      await tx.execute(
        Sql.named('INSERT INTO identity.auth_identities (user_id, provider, provider_subject, password_hash) '
            "VALUES (@id::uuid, 'password', @email, @hash)"),
        parameters: {'id': usuario.id, 'email': usuario.email, 'hash': hash},
      );

      // registra o aceite dos termos que estao valendo agora
      await tx.execute(
        Sql.named('INSERT INTO identity.user_consents (user_id, consent_type, granted, legal_document_id, source) '
            'SELECT @id::uuid, d.document_type::text::common.consent_type, true, d.id, \'app\' '
            'FROM platform.legal_documents d '
            "WHERE d.is_current AND d.document_type::text IN ('terms_of_use', 'privacy_policy')"),
        parameters: {'id': usuario.id},
      );
    });
  } on ServerException catch (e) {
    throw ValidacaoException(traduzirErro(e));
  }

  return usuario;
}

// ---------------- LOGIN ----------------

Future<Usuario> entrar({required String ra, required String email, required String senha}) async {
  var conn = await conectar();
  // mensagem igual pra qualquer erro, assim ninguem descobre se o email existe
  const erroLogin = ValidacaoException('RA, e-mail ou senha incorretos.');

  var emailLimpo = email.trim().toLowerCase();
  var raLimpo = ra.trim();
  if (emailLimpo.isEmpty || raLimpo.isEmpty || senha.isEmpty) {
    throw const ValidacaoException('Preencha RA, e-mail e senha.');
  }

  var r = await conn.execute(
    Sql.named('SELECT u.id::text, u.full_name, u.email::text, u.ra, u.status::text, l.label_pt, '
        'u.last_login_at, ai.password_hash '
        'FROM identity.users u '
        "JOIN identity.auth_identities ai ON ai.user_id = u.id AND ai.provider = 'password' "
        "LEFT JOIN common.enum_labels l ON l.enum_name = 'user_status' AND l.value = u.status::text "
        "WHERE u.email = CAST(@email AS public.citext) AND u.deleted_at IS NULL AND u.status <> 'anonymized'"),
    parameters: {'email': emailLimpo},
  );

  if (r.isEmpty) {
    throw erroLogin;
  }
  var linha = r[0];
  if (linha[3] != raLimpo) {
    throw erroLogin;
  }
  var senhaCerta = await conferirSenha(senha, linha[7] as String);
  if (!senhaCerta) {
    throw erroLogin;
  }

  var usuario = Usuario(
    nome: linha[1] as String,
    email: linha[2] as String,
    ra: linha[3] as String,
    status: linha[4] as String,
  );
  usuario.id = linha[0] as String;
  usuario.statusDescricao = linha[5] as String?;
  usuario.ultimoLogin = linha[6] as DateTime?;

  if (!usuario.podeEntrar) {
    throw ValidacaoException('Sua conta esta "${usuario.statusDescricao}". Procure o suporte.');
  }

  // abre a sessao usando a funcao do proprio banco (ela tambem atualiza o last_login_at)
  // o banco guarda so o hash do token, nunca o token
  var token = bytesAleatorios(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  var tokenHash = await sha256Hex(token);
  var s = await conn.execute(
    Sql.named("SELECT identity.start_session(@id::uuid, @token, now() + interval '30 days', NULL, 'unifood-terminal')::text"),
    parameters: {'id': usuario.id, 'token': tokenHash},
  );
  idSessao = s[0][0] as String;
  usuarioLogado = usuario;
  return usuario;
}

Future<void> sair() async {
  if (idSessao != null) {
    var conn = await conectar();
    await conn.execute(
      Sql.named('UPDATE identity.sessions SET revoked_at = now() WHERE id = @id::uuid AND revoked_at IS NULL'),
      parameters: {'id': idSessao},
    );
  }
  idSessao = null;
  usuarioLogado = null;
}

// transforma o erro do banco numa mensagem que da pra mostrar pro usuario
String traduzirErro(ServerException e) {
  switch (e.constraintName) {
    case 'uq_users_email':
    case 'uq_auth_identities_provider_subject':
      return 'Ja existe uma conta com esse e-mail.';
    case 'ck_email_address':
      return 'E-mail invalido.';
    case 'ck_users_full_name':
      return 'O nome deve ter pelo menos 2 caracteres.';
  }
  return 'Erro no banco: ${e.message}';
}
