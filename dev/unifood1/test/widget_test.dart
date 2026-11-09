import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unifood1/main.dart';

void main() {
  testWidgets('teste do contador', (WidgetTester tester) async {
    await tester.pumpWidget(const MeuApp());

    // comeca no 0
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // aperta o botao de +
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // agora tem que ta 1
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
