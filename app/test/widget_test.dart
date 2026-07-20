import 'package:flutter_test/flutter_test.dart';
import 'package:nn_follow_cart/main.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Dashboard smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CartState(),
        child: const NnFollowCartApp(),
      ),
    );

    expect(find.text('NN Follow Cart'), findsOneWidget);
    expect(find.text('FOLLOW ME'), findsOneWidget);
    expect(find.text('SCAN FOR CART'), findsOneWidget);
    expect(find.text('MANUAL DRIVE'), findsOneWidget);
  });
}
