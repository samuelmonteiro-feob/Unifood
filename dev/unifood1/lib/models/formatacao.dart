double arredondarCentavos(double valor) => (valor * 100).round() / 100;

String formatarReais(double valor) =>
    'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
