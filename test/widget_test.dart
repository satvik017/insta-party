import 'package:flutter_test/flutter_test.dart';
import 'package:insta_sync_party/main.dart';

void main() {
  testWidgets('InstaParty app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const InstaSyncPartyApp());
    expect(find.text('InstaParty'), findsOneWidget);
    // Allow splash timer to complete transition
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
