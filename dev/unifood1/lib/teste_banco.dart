// teste da conexao com o banco
// rodar com: dart run lib/teste_banco.dart
// (antes tem que ter rodado o banco/criar_banco.sql)

import 'banco/banco.dart';
import 'models/pedido.dart';

void main() async {
  try {
    print('--- estabelecimentos ---');
    var estabelecimentos = await buscarEstabelecimentos();
    for (var e in estabelecimentos) {
      print('${e.id} - $e - ${e.nivelLotacao}');
    }

    var loja = estabelecimentos[0];
    print('\n--- produtos de ${loja.nome} ---');
    var produtos = await buscarProdutos(loja);
    for (var p in produtos) {
      print('${p.id} - $p');
    }

    print('\n--- fazendo um pedido ---');
    var pedido = Pedido(nomeCliente: 'Samuel Monteiro', estabelecimento: loja);
    pedido.adicionarItem(produtos[0], quantidade: 2, observacao: 'sem cebola');
    pedido.adicionarItem(produtos[1]);
    pedido.aplicarCupom('UNIFEOB10');
    pedido.confirmar();
    print(pedido.gerarResumo());

    var id = await salvarPedido(pedido);
    print('pedido salvo no banco com id $id');

    await atualizarStatusPedido(id, StatusPedido.emPreparo);
    print('status mudou pra em preparo');

    print('\n--- pedidos no banco ---');
    var pedidos = await buscarPedidos();
    for (var p in pedidos) {
      print('#${p['id']} ${p['cliente']} - ${p['estabelecimento']} - '
          '${(p['status'] as StatusPedido).descricao} - R\$ ${p['total']}');
    }

    print('\n--- itens do pedido $id ---');
    var itens = await buscarItensDoPedido(id);
    for (var i in itens) {
      print('${i['quantidade']}x ${i['produto']} - R\$ ${i['preco']} ${i['observacao'] ?? ''}');
    }
  } catch (e) {
    print('deu erro: $e');
  } finally {
    await desconectar();
  }
}
