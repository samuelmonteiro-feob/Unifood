// ATIVIDADE - Aplicacao final da logica
// programa que processa a lista de vendas do unifood e calcula:
//   soma (faturamento), media (ticket medio), maior venda e menor venda
// depois compara com os mesmos indicadores calculados pelo banco de dados,
// que sao os numeros que vao aparecer no dashboard do projeto
//
// rodar com: dart run lib/atividade_kpis_vendas.dart
// (a parte 1 roda sem banco, a parte 2 precisa do lib/banco/config.dart)
//
// OBS sobre os centavos: no computador 0.1 + 0.2 da 0.30000000000000004,
// entao somar muitos valores em double pode dar diferenca de centavo.
// por isso os calculos sao feitos em CENTAVOS (numero inteiro) e so no final
// volta pra reais. assim o resultado bate certinho com o banco.

import 'package:postgres/postgres.dart';

import 'banco/banco.dart';
import 'models/formatacao.dart';

// ---------------- FUNCOES DE CALCULO ----------------

int paraCentavos(double valor) => (valor * 100).round();
double paraReais(int centavos) => centavos / 100;

// soma de todas as vendas
double somarVendas(List<double> vendas) {
  int total = 0;
  for (var venda in vendas) {
    total = total + paraCentavos(venda);
  }
  return paraReais(total);
}

// media = soma / quantidade (arredondada no centavo)
double mediaVendas(List<double> vendas) {
  if (vendas.isEmpty) {
    return 0; // sem venda nao tem media, evita dividir por zero
  }
  int total = 0;
  for (var venda in vendas) {
    total = total + paraCentavos(venda);
  }
  int media = (total / vendas.length).round();
  return paraReais(media);
}

// maior venda: comeca com a primeira e vai trocando se achar uma maior
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

// menor venda: mesma ideia do maior, so que ao contrario
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

// ---------------- VALIDACAO ----------------

int acertos = 0;
int erros = 0;

// compara o valor calculado no dart com o valor esperado (ou com o do banco)
// compara em centavos pra nao ter problema de casa decimal
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

// ---------------- PARTE 1: LISTA FIXA (conta feita na mao) ----------------

void parte1() {
  print('==============================================');
  print(' PARTE 1 - lista de vendas fixa (sem banco)');
  print('==============================================');

  // 10 vendas de exemplo (valores parecidos com os do banco)
  var vendas = [17.00, 24.50, 16.00, 8.75, 32.90, 12.30, 45.00, 6.60, 21.15, 9.80];
  print('  Vendas: $vendas\n');
  mostrarKpis('Indicadores calculados:', vendas);

  // resultados calculados na mao (calculadora):
  // soma  = 17.00 + 24.50 + 16.00 + 8.75 + 32.90 + 12.30 + 45.00 + 6.60 + 21.15 + 9.80 = 194.00
  // media = 194.00 / 10 = 19.40
  // maior = 45.00
  // menor = 6.60
  print('\n  Conferindo com a conta feita na mao:');
  conferir('Soma', somarVendas(vendas), 194.00);
  conferir('Media', mediaVendas(vendas), 19.40);
  conferir('Maior', maiorVenda(vendas), 45.00);
  conferir('Menor', menorVenda(vendas), 6.60);

  // casos especiais
  print('\n  Casos especiais:');
  conferir('Lista vazia', somarVendas([]), 0);
  conferir('Media vazia', mediaVendas([]), 0);
  conferir('So 1 venda', mediaVendas([12.34]), 12.34);
  // 0.1 + 0.2 em double daria 0.30000000000000004, em centavos da 0.30 certinho
  conferir('0,10 + 0,20', somarVendas([0.10, 0.20]), 0.30);
  // media que precisa arredondar: 10 / 3 = 3.333... -> 3.33
  conferir('Media 10/3', mediaVendas([3.33, 3.33, 3.34]), 3.33);
}

// ---------------- PARTE 2: VENDAS DO BANCO x DASHBOARD ----------------

// busca a lista de vendas: o total de cada pedido que foi retirado
// (pedido cancelado nao e venda, e pedido em andamento ainda nao foi concluido)
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

// os indicadores do jeito que o dashboard calcula: direto no banco com SUM, AVG, MAX e MIN
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

  // geral (todas as lojas)
  var vendas = await buscarVendas(conn);
  print('');
  mostrarKpis('Indicadores gerais (todas as lojas):', vendas);
  print('\n  Comparando com o dashboard (calculo do banco):');
  compararComDashboard(vendas, await buscarKpisDashboard(conn));

  // por loja
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

// ---------------- MAIN ----------------

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
