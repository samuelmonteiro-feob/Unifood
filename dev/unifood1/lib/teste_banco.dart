// teste da conexao com o banco do unifood (schema negocio_teste)
// rodar com: dart run lib/teste_banco.dart

import 'banco/banco.dart';
import 'models/pedido.dart';

void main() async {
  try {
    print('--- lojas ---');
    var lojas = await buscarEstabelecimentos();
    for (var e in lojas) {
      print('${e.slug} - $e - ${e.aberto ? 'aberta' : 'fechada'}');
    }

    var loja = lojas.firstWhere((e) => e.slug == 'mr-john-pizzas');
    print('\n--- cardapio de ${loja.nome} ---');
    var produtos = await buscarProdutos(loja);
    for (var p in produtos) {
      print(p);
    }

    print('\n--- fazendo um pedido ---');
    var pedido = Pedido(nomeCliente: 'Samuel Monteiro', estabelecimento: loja);
    var pizza = produtos.firstWhere((p) => p.nome == 'Fatia Calabresa');
    var refri = produtos.firstWhere((p) => p.nome == 'Refrigerante Lata');
    pedido.adicionarItem(pizza, quantidade: 2, observacao: 'sem cebola');
    pedido.adicionarItem(refri);
    pedido.aplicarCupom('UNIFEOB10');
    pedido.confirmar();
    print(pedido.gerarResumo());

    var numero = await salvarPedido(pedido);
    print('pedido salvo no banco com numero $numero');

    await atualizarStatusPedido(numero, StatusPedido.emPreparo);
    print('status mudou pra em preparo');

    print('\n--- fila de retirada da ${loja.nome} ---');
    var fila = await buscarFila(loja.slug!);
    for (var f in fila) {
      print('${f['posicao']}. senha ${f['senha']} - pedido ${f['numero']} - '
          '${(f['status'] as StatusPedido).descricao}');
    }

    print('\n--- ultimos 5 pedidos ---');
    var pedidos = await buscarPedidos(limite: 5);
    for (var p in pedidos) {
      print('#${p['numero']} ${p['cliente']} - ${p['estabelecimento']} - '
          '${(p['status'] as StatusPedido).descricao} - R\$ ${p['total']}');
    }

    print('\n--- itens do pedido $numero ---');
    var itens = await buscarItensDoPedido(numero);
    for (var i in itens) {
      print('${i['quantidade']}x ${i['produto']} - R\$ ${i['preco']} ${i['observacao'] ?? ''}');
    }
  } catch (e) {
    print('deu erro: $e');
  } finally {
    await desconectar();
  }
}
