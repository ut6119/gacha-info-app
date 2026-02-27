import 'package:flutter_test/flutter_test.dart';

import 'package:gacha_info_app/main.dart';

void main() {
  testWidgets('app renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const GachaInfoApp());
    await tester.pumpAndSettle();

    expect(find.text('ガチャガチャ情報アプリ'), findsOneWidget);
  });
}
