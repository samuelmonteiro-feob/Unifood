import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  // carrega as configuracoes do arquivo .env
  // (o load recebe uma LISTA de arquivos, por isso ['.env'])
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);

  final databaseUrl = env['DATABASE_URL'];

  if (databaseUrl == null || databaseUrl.isEmpty) {
    throw Exception('DATABASE_URL não foi encontrada. Crie o arquivo .env (veja o .env.exemplo).');
  }

  // prepara a URL pro driver do dart:
  // ele aceita sslmode, mas da erro com channel_binding, entao tira so esse
  final uri = Uri.parse(databaseUrl);

  final parameters = Map<String, String>.from(uri.queryParameters)..remove('channel_binding');

  parameters.putIfAbsent('sslmode', () => 'require');

  final compatibleUrl = uri.replace(queryParameters: parameters).toString();

  // cria o pool de conexoes
  final pool = Pool.withUrl(compatibleUrl);

  try {
    // informacoes do banco
    final result = await pool.execute('''
      SELECT
        current_database() AS banco,
        current_user AS usuario,
        current_setting('server_version') AS versao
    ''');

    final dados = result.first.toColumnMap();

    print('Conexão estabelecida!');
    print('Banco: ${dados['banco']}');
    print('Usuário: ${dados['usuario']}');
    print('PostgreSQL: ${dados['versao']}');

    // testa o acesso a tabelas reais do unifood
    final lojas = await pool.execute('SELECT COUNT(*) AS total FROM merchant.stores');
    print('Total de lojas: ${lojas.first[0]}');

    final usuarios = await pool.execute('SELECT COUNT(*) AS total FROM identity.users');
    print('Total de usuários: ${usuarios.first[0]}');

    // o grupo unifood_api nao tem permissao no schema negocio_teste,
    // que e onde o app ainda le as lojas e grava os pedidos
    final teste = await pool.execute(
        "SELECT has_schema_privilege(current_user, 'negocio_teste', 'USAGE')");
    if (teste.first[0] == true) {
      print('Acesso ao negocio_teste: sim');
    } else {
      print('Acesso ao negocio_teste: NÃO (lojas e pedidos do app ainda usam esse schema)');
    }
  } catch (e) {
    print('Erro ao conectar ao Neon: $e');
    rethrow;
  } finally {
    await pool.close();
  }
}
