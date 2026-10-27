
import 'models/estabelecimento.dart';
import 'models/excecoes.dart';
import 'models/formatacao.dart';
import 'models/pedido.dart';
import 'models/produto.dart';

void tentar(String descricao, void Function() acao) {
  try {
    acao();
    print('OK - $descricao');
  } on ValidacaoException catch (e) {
    print('ERRO - $descricao - ${e.mensagem}');
  } on UnsupportedError {
    print('ERRO - $descricao - operação bloqueada (lista protegida).');
  }
}

void main() {
  print('1: Encapsulamento e validação no Produto');
  final pizza = Produto(nome: 'Pizza Calabresa (fatia)', preco: 9.50, tempoPreparoMin: 6);
  final suco = Produto(nome: 'Suco Natural', preco: 6.00, tempoPreparoMin: 3);
  final pastel = Produto(nome: 'Pastel de Carne', preco: 8.00, tempoPreparoMin: 5);

  print('Preço lido pelo getter: ${pizza.precoFormatado}');
  tentar('Alterar preço para R\$ 10,00', () => pizza.preco = 10.00);
  tentar('Alterar preço para -5', () => pizza.preco = -5);
  tentar('Criar produto com nome vazio', () => Produto(nome: ' ', preco: 5));
  tentar('Tempo de preparo de 90 min', () => suco.tempoPreparoMin = 90);
  print('Pizza com 10% de desconto: ${formatarReais(pizza.calcularPrecoComDesconto(10))}');
  tentar('Desconto de 150%', () => pizza.calcularPrecoComDesconto(150));

  print('\n2: Estabelecimento');
  final mrJohn = Estabelecimento(
    nome: 'Mr. John Pizzas',
    local: LocalAlimentacao.praca2PredioE,
    capacidadeSimultanea: 2,
  );
  mrJohn.adicionarProduto(pizza);
  mrJohn.adicionarProduto(suco);
  mrJohn.adicionarProduto(pastel);
  tentar('Adicionar produto repetido', () => mrJohn.adicionarProduto(suco));
  tentar('Alterar a lista de fora (somente leitura)', () => mrJohn.produtos.add(suco));
  print('Lotação: ${mrJohn.nivelLotacao}');

  print('\n3: Pedido e cálculos internos');
  final pedido = Pedido(nomeCliente: 'Samuel Monteiro', estabelecimento: mrJohn);
  pedido.adicionarItem(pizza, quantidade: 2, observacao: 'Sem cebola');
  pedido.adicionarItem(suco);
  tentar('Quantidade 50 de suco', () => pedido.adicionarItem(suco, quantidade: 50));
  tentar('Cupom inexistente', () => pedido.aplicarCupom('XYZ'));
  tentar('Cupom UNIFEOB10', () => pedido.aplicarCupom('unifeob10'));
  tentar('Retirada daqui a 1 minuto', () =>
      pedido.agendarRetirada(DateTime.now().add(const Duration(minutes: 1))));
  tentar('Retirada daqui a 30 minutos', () =>
      pedido.agendarRetirada(DateTime.now().add(const Duration(minutes: 30))));
  print(pedido.gerarResumo());

  print('\n4: Fluxo do pedido');
  tentar('Avançar sem confirmar', () => pedido.avancarStatus());
  tentar('Confirmar pedido', () => pedido.confirmar());
  tentar('Adicionar item após confirmar', () => pedido.adicionarItem(pastel));
  print('Lotação de ${mrJohn.nome}: ${mrJohn.nivelLotacao} '
      '(${mrJohn.pedidosEmPreparo}/${mrJohn.capacidadeSimultanea})');

  final pedido2 = Pedido(nomeCliente: 'Maria Souza', estabelecimento: mrJohn)
    ..adicionarItem(pastel);
  tentar('Confirmar pedido 2', () => pedido2.confirmar());

  final pedido3 = Pedido(nomeCliente: 'João Lima', estabelecimento: mrJohn)
    ..adicionarItem(suco);
  tentar('Confirmar pedido 3 (estabelecimento lotado)', () => pedido3.confirmar());
  print('Lotação: ${mrJohn.nivelLotacao}');

  tentar('Pedido 1 - em preparo', () => pedido.avancarStatus());
  tentar('Cancelar pedido 1 já em preparo', () => pedido.cancelar());
  tentar('Pedido 1 - pronto', () => pedido.avancarStatus());
  print('Vaga liberada. Lotação: ${mrJohn.nivelLotacao}');
  tentar('Confirmar pedido 3 agora', () => pedido3.confirmar());
  tentar('Pedido 1 - retirado', () => pedido.avancarStatus());
  tentar('Pedido 1 - avançar de novo', () => pedido.avancarStatus());

  print('\nStatus final do pedido 1: ${pedido.status.descricao}');
}
