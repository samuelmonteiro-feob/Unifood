// Integrantes:
// Erick Araujo Moraes - RA 26000855
// Samuel David Monteiro - RA 26000806

import 'package:postgres/postgres.dart';

import 'banco/banco.dart';
import 'models/formatacao.dart';

int paraCentavos(double valor) => (valor * 100).round();
double paraReais(int centavos) => centavos / 100;

double somarVendas(List<double> vendas) {
  int total = 0;
  for (var venda in vendas) {
    total = total + paraCentavos(venda);
  }
  return paraReais(total);
}

double mediaVendas(List<double> vendas) {
  if (vendas.isEmpty) {
    return 0;
  }
  int total = 0;
  for (var venda in vendas) {
    total = total + paraCentavos(venda);
  }
  int media = (total / vendas.length).round();
  return paraReais(media);
}

double maiorVenda(List<double> vendas) {
  if (vendas.isEmpty) {
    return 0;
  }
  var maior = vendas[0];
  for (var i = 1; i < vendas.length; i++) {
    if (vendas[i] > maior) {
      maior = vendas[i];
    }
  }
  return maior;
}

double menorVenda(List<double> vendas) {
  if (vendas.isEmpty) {
    return 0;
  }
  var menor = vendas[0];
  for (var i = 1; i < vendas.length; i++) {
    if (vendas[i] < menor) {
      menor = vendas[i];
    }
  }
  return menor;
}

int acertos = 0;
int erros = 0;

void conferir(String nome, double calculado, double esperado, {String rotulo = 'esperado'}) {
  var ok = paraCentavos(calculado) == paraCentavos(esperado);
  if (ok) {
    acertos++;
  } else {
    erros++;
  }
  var status = ok ? 'OK       ' : 'DIFERENTE';
  print('  $status ${nome.padRight(16)} dart: ${formatarReais(calculado).padLeft(13)}'
      '   ${'$rotulo:'.padRight(9)} ${formatarReais(esperado).padLeft(13)}');
}

void mostrarKpis(String titulo, List<double> vendas) {
  print('  $titulo');
  print('    Quantidade de vendas: ${vendas.length}');
  print('    Faturamento (soma):   ${formatarReais(somarVendas(vendas))}');
  print('    Ticket medio:         ${formatarReais(mediaVendas(vendas))}');
  print('    Maior venda:          ${formatarReais(maiorVenda(vendas))}');
  print('    Menor venda:          ${formatarReais(menorVenda(vendas))}');
}

void parte1() {
  print('==============================================');
  print(' PARTE 1 - lista de vendas fixa (sem banco)');
  print('==============================================');

  var vendas = [17.00, 24.50, 16.00, 8.75, 32.90, 12.30, 45.00, 6.60, 21.15, 9.80];
  print('  Vendas: $vendas\n');
  mostrarKpis('Indicadores calculados:', vendas);

  print('\n  Conferindo com a conta feita na mao:');
  conferir('Soma', somarVendas(vendas), 194.00);
  conferir('Media', mediaVendas(vendas), 19.40);
  conferir('Maior', maiorVenda(vendas), 45.00);
  conferir('Menor', menorVenda(vendas), 6.60);

  print('\n  Casos especiais:');
  conferir('Lista vazia', somarVendas([]), 0);
  conferir('Media vazia', mediaVendas([]), 0);
  conferir('So 1 venda', mediaVendas([12.34]), 12.34);
  conferir('0,10 + 0,20', somarVendas([0.10, 0.20]), 0.30);
  conferir('Media 10/3', mediaVendas([3.33, 3.33, 3.34]), 3.33);
}

Future<List<double>> buscarVendas(Connection conn, {String? loja}) async {
  var sql = "SELECT total::float8 FROM negocio_teste.pedidos WHERE situacao = 'retirado'";
  Map<String, dynamic> parametros = {};
  if (loja != null) {
    sql += ' AND loja = @loja';
    parametros['loja'] = loja;
  }
  var resultado = await conn.execute(Sql.named(sql), parameters: parametros);

  List<double> vendas = [];
  for (var linha in resultado) {
    vendas.add(linha[0] as double);
  }
  return vendas;
}

Future<Map<String, double>> buscarKpisDashboard(Connection conn, {String? loja}) async {
  var sql = 'SELECT count(*)::float8, coalesce(sum(total), 0)::float8, coalesce(round(avg(total), 2), 0)::float8, '
      "coalesce(max(total), 0)::float8, coalesce(min(total), 0)::float8 FROM negocio_teste.pedidos WHERE situacao = 'retirado'";
  Map<String, dynamic> parametros = {};
  if (loja != null) {
    sql += ' AND loja = @loja';
    parametros['loja'] = loja;
  }
  var r = await conn.execute(Sql.named(sql), parameters: parametros);
  return {
    'quantidade': r[0][0] as double,
    'soma': r[0][1] as double,
    'media': r[0][2] as double,
    'maior': r[0][3] as double,
    'menor': r[0][4] as double,
  };
}

void compararComDashboard(List<double> vendas, Map<String, double> dashboard) {
  var qtdOk = vendas.length == dashboard['quantidade']!.toInt();
  if (qtdOk) {
    acertos++;
  } else {
    erros++;
  }
  print('  ${qtdOk ? 'OK       ' : 'DIFERENTE'} ${'Quantidade'.padRight(16)} dart: ${vendas.length.toString().padLeft(13)}'
      '   banco:    ${dashboard['quantidade']!.toInt().toString().padLeft(13)}');
  conferir('Soma', somarVendas(vendas), dashboard['soma']!, rotulo: 'banco');
  conferir('Media', mediaVendas(vendas), dashboard['media']!, rotulo: 'banco');
  conferir('Maior', maiorVenda(vendas), dashboard['maior']!, rotulo: 'banco');
  conferir('Menor', menorVenda(vendas), dashboard['menor']!, rotulo: 'banco');
}

Future<void> parte2() async {
  print('\n==============================================');
  print(' PARTE 2 - vendas do banco x indicadores do dashboard');
  print('==============================================');

  Connection conn;
  try {
    conn = await conectar();
  } catch (e) {
    print('  Nao deu pra conectar no banco, pulando a parte 2.');
    print('  ($e)');
    return;
  }

  var vendas = await buscarVendas(conn);
  print('');
  mostrarKpis('Indicadores gerais (todas as lojas):', vendas);
  print('\n  Comparando com o dashboard (calculo do banco):');
  compararComDashboard(vendas, await buscarKpisDashboard(conn));

  var lojas = await conn.execute('SELECT slug, nome FROM negocio_teste.lojas ORDER BY nome');
  for (var loja in lojas) {
    var slug = loja[0] as String;
    var vendasLoja = await buscarVendas(conn, loja: slug);
    print('\n  --- ${loja[1]} ---');
    print('  ${vendasLoja.length} vendas | soma ${formatarReais(somarVendas(vendasLoja))} | '
        'media ${formatarReais(mediaVendas(vendasLoja))} | maior ${formatarReais(maiorVenda(vendasLoja))} | '
        'menor ${formatarReais(menorVenda(vendasLoja))}');
    compararComDashboard(vendasLoja, await buscarKpisDashboard(conn, loja: slug));
  }

  await desconectar();
}

Future<void> main() async {
  parte1();
  await parte2();

  print('\n==============================================');
  print(' RESULTADO: $acertos conferencias OK, $erros diferentes');
  if (erros == 0) {
    print(' Todos os calculos foram validados!');
  } else {
    print(' Tem calculo que nao bateu, conferir acima.');
  }
  print('==============================================');
}
