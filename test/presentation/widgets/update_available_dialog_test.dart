import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:burari_date/presentation/widgets/update_available_dialog.dart';

void main() {
  group('showUpdateAvailableDialog', () {
    Future<bool?> open(WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showUpdateAvailableDialog(context),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('更新を促す文言と、「更新する」「あとで」を出す', (tester) async {
      await open(tester);

      expect(find.text('新しいバージョンがあります'), findsOneWidget);
      expect(find.textContaining('更新してください'), findsOneWidget);
      expect(find.text('更新する'), findsOneWidget);
      expect(find.text('あとで'), findsOneWidget);
    });

    testWidgets('「更新する」を押すと、閉じて、trueを返す', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showUpdateAvailableDialog(context),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('更新する'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('新しいバージョンがあります'), findsNothing);
    });

    testWidgets('「あとで」を押すと、閉じて、falseを返す(利用は止めない)', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showUpdateAvailableDialog(context),
                child: const Text('開く'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('あとで'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.text('新しいバージョンがあります'), findsNothing);
      // 元の画面は、そのまま使える。
      expect(find.text('開く'), findsOneWidget);
    });

    testWidgets('案内の文字は、ドット書体ではなく、ほかの画面と同じ普通の書体', (tester) async {
      await open(tester);

      for (final text in ['新しいバージョンがあります', '更新する', 'あとで']) {
        final style = tester.widget<Text>(find.text(text)).style;
        final family = style?.fontFamily ?? '';
        expect(
          family.contains('DotGothic16'),
          isFalse,
          reason: '「$text」が、ドット書体になっている: $family',
        );
      }
    });

    testWidgets('見出しと本文は左揃えで、ボタンは中央に置く', (tester) async {
      await open(tester);

      final title = find.text('新しいバージョンがあります');
      final body = find.textContaining('更新してください');
      final dialog = tester.getRect(find.byType(Dialog));

      // 見出しと本文の左端がそろい、ダイアログの左側に寄っている。
      expect(tester.getTopLeft(title).dx, tester.getTopLeft(body).dx);
      expect(
        tester.getTopLeft(title).dx - dialog.left,
        lessThan(dialog.width / 4),
      );
      // ボタンは、ダイアログの中央に置く。
      expect(
        tester.getCenter(find.byType(ElevatedButton)).dx,
        closeTo(dialog.center.dx, 1),
      );
    });
  });
}
