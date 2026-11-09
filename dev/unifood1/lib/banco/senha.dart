import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

// a senha NUNCA vai pro banco, so o hash dela
// o banco pede hash Argon2id (comentario da coluna identity.auth_identities.password_hash)
// o formato salvo e o padrao: $argon2id$v=19$m=19456,t=2,p=1$<salt>$<hash>
// assim qualquer biblioteca de argon2 (node, python, etc) consegue conferir a senha

const int memoria = 19456; // em KB (19 MB), valor recomendado pela OWASP
const int iteracoes = 2;
const int paralelismo = 1;

// base64 sem o "=" no final, que e o que o formato do argon2 usa
String _b64(List<int> bytes) => base64.encode(bytes).replaceAll('=', '');

List<int> _deB64(String texto) {
  while (texto.length % 4 != 0) {
    texto += '=';
  }
  return base64.decode(texto);
}

List<int> bytesAleatorios(int quantidade) {
  var r = Random.secure();
  return List.generate(quantidade, (_) => r.nextInt(256));
}

Future<List<int>> _calcular(String senha, List<int> salt, int m, int t, int p, int tamanho) async {
  var argon = Argon2id(memory: m, iterations: t, parallelism: p, hashLength: tamanho);
  var chave = await argon.deriveKeyFromPassword(password: senha, nonce: salt);
  return chave.extractBytes();
}

Future<String> gerarHashSenha(String senha) async {
  var salt = bytesAleatorios(16);
  var hash = await _calcular(senha, salt, memoria, iteracoes, paralelismo, 32);
  return '\$argon2id\$v=19\$m=$memoria,t=$iteracoes,p=$paralelismo\$${_b64(salt)}\$${_b64(hash)}';
}

// confere a senha digitada com o hash salvo no banco
Future<bool> conferirSenha(String senha, String hashSalvo) async {
  try {
    var partes = hashSalvo.split('\$'); // ['', 'argon2id', 'v=19', 'm=..,t=..,p=..', salt, hash]
    if (partes.length != 6 || partes[1] != 'argon2id') {
      return false;
    }
    var m = 0, t = 0, p = 0;
    for (var item in partes[3].split(',')) {
      var kv = item.split('=');
      if (kv[0] == 'm') m = int.parse(kv[1]);
      if (kv[0] == 't') t = int.parse(kv[1]);
      if (kv[0] == 'p') p = int.parse(kv[1]);
    }
    var salt = _deB64(partes[4]);
    var esperado = _deB64(partes[5]);
    var calculado = await _calcular(senha, salt, m, t, p, esperado.length);

    // compara tudo (sem parar no primeiro byte diferente)
    var diferenca = 0;
    for (var i = 0; i < esperado.length; i++) {
      diferenca |= esperado[i] ^ calculado[i];
    }
    return diferenca == 0;
  } catch (e) {
    return false;
  }
}

// hash sha256 em hexadecimal (usado pro token da sessao)
Future<String> sha256Hex(String texto) async {
  var h = await Sha256().hash(utf8.encode(texto));
  return h.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
