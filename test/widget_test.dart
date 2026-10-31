import 'package:flutter_test/flutter_test.dart';
import 'package:muzaid/main.dart';

void main() {
  testWidgets('AuctionApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AuctionApp());
    expect(find.text('الرئيسية'), findsWidgets);
    store.dispose();
  });
}
