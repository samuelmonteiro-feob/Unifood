// copia esse arquivo e renomeia pra config.dart, depois coloca os dados do seu banco
// o config.dart ta no .gitignore pra senha nao ir pro github

// OBS: se rodar no emulador do android tem que trocar localhost por 10.0.2.2
// pra usar o banco do Neon: host = o endereco do Neon (ex: ep-xxxx-pooler.c-2.sa-east-1.aws.neon.tech),
// usuario = unifood_backend e a senha dele (o ssl liga sozinho quando nao e localhost)
String host = 'localhost';
int porta = 5432;
String nomeBanco = 'unifood';
String usuario = 'postgres';
String senha = 'SUA_SENHA_AQUI';
