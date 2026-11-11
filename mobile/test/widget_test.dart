import 'package:flutter_test/flutter_test.dart';
import 'package:family_finance/main.dart';

void main() {
  testWidgets('shows the Family Finance login screen', (tester) async {
    await tester.pumpWidget(const FamilyFinanceApp());
    await tester.pumpAndSettle();

    expect(find.text('Family Finance'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });
}
