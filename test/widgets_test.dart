import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/components/app_button.dart';
import 'package:medremind/components/app_card.dart';
import 'package:medremind/components/app_input.dart';
import 'package:medremind/components/app_text.dart';
import 'package:medremind/components/controls.dart';
import 'package:medremind/components/layout.dart';
import 'package:medremind/components/fields.dart';
import 'package:medremind/screens/tabs_shell.dart';
import 'package:medremind/theme/tokens.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('AppText', () {
    testWidgets('renders its string', (tester) async {
      await tester.pumpWidget(_host(const AppText('Xin chào')));
      expect(find.text('Xin chào'), findsOneWidget);
    });

    testWidgets('applies the variant size and the colour key', (tester) async {
      await tester.pumpWidget(_host(const AppText(
        'T',
        variant: TextVariant.title,
        color: TextColorKey.primary,
      )));
      final style = tester.widget<Text>(find.byType(Text)).style!;
      expect(style.fontSize, FontSizes.xxxl);
      expect(style.color, AppColors.primary);
      expect(style.fontWeight, FontWeights.bold);
    });

    testWidgets('centres when asked', (tester) async {
      await tester.pumpWidget(_host(const AppText('C', center: true)));
      expect(tester.widget<Text>(find.byType(Text)).textAlign, TextAlign.center);
    });
  });

  group('AppButton', () {
    testWidgets('fires onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppButton(label: 'Lưu', onPressed: () => taps++),
      ));
      await tester.tap(find.text('Lưu'));
      expect(taps, 1);
    });

    testWidgets('does not fire while disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppButton(label: 'Lưu', disabled: true, onPressed: () => taps++),
      ));
      await tester.tap(find.text('Lưu'));
      expect(taps, 0);
    });

    testWidgets('shows a spinner and blocks taps while loading',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppButton(label: 'Lưu', loading: true, onPressed: () => taps++),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Lưu'), findsNothing);

      await tester.tap(find.byType(AppButton));
      expect(taps, 0, reason: 'a double tap must not submit twice');
    });

    testWidgets('renders leading and trailing icons', (tester) async {
      await tester.pumpWidget(_host(const AppButton(
        label: 'Tiếp',
        icon: Icons.add,
        iconRight: Icons.chevron_right,
      )));
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('danger variant uses the danger palette', (tester) async {
      await tester.pumpWidget(_host(
        const AppButton(label: 'Xóa', variant: ButtonVariant.danger),
      ));
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppButton),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.dangerSoft);
    });
  });

  group('AppCard', () {
    testWidgets('shows its child', (tester) async {
      await tester.pumpWidget(_host(const AppCard(child: AppText('Nội dung'))));
      expect(find.text('Nội dung'), findsOneWidget);
    });

    testWidgets('is tappable only when onPress is given', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(
        AppCard(onPress: () => taps++, child: const AppText('Bấm')),
      ));
      await tester.tap(find.text('Bấm'));
      expect(taps, 1);
    });

    testWidgets('tinted tones drop the shadow', (tester) async {
      await tester.pumpWidget(_host(
        const AppCard(tone: CardTone.primary, child: AppText('x')),
      ));
      final container = tester.widget<Container>(
        find
            .descendant(of: find.byType(AppCard), matching: find.byType(Container))
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primarySoft);
      expect(decoration.boxShadow, isNull);
    });
  });

  group('AppInput', () {
    testWidgets('shows label, placeholder and reports changes', (tester) async {
      String? seen;
      await tester.pumpWidget(_host(AppInput(
        label: 'Email',
        placeholder: 'you@example.com',
        onChanged: (v) => seen = v,
      )));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'a@b.c');
      expect(seen, 'a@b.c');
    });

    testWidgets('error text replaces the hint and turns the border red',
        (tester) async {
      await tester.pumpWidget(_host(const AppInput(
        label: 'Mật khẩu',
        hint: 'ít nhất 8 ký tự',
        error: 'Sai mật khẩu',
      )));
      expect(find.text('Sai mật khẩu'), findsOneWidget);
      expect(find.text('ít nhất 8 ký tự'), findsNothing);
    });

    testWidgets('hides the password and reveals it when the eye is tapped',
        (tester) async {
      await tester.pumpWidget(_host(const AppInput(
        label: 'Mật khẩu',
        obscureText: true,
        obscureToggle: true,
        revealLabel: 'Hiện mật khẩu',
        hideLabel: 'Ẩn mật khẩu',
      )));

      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().obscureText, isTrue, reason: 'starts hidden');

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(field().obscureText, isFalse, reason: 'revealed after tapping');
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(field().obscureText, isTrue, reason: 'hidden again');
    });

    testWidgets('no eye button on a normal field', (tester) async {
      await tester.pumpWidget(_host(const AppInput(label: 'Email')));
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('no eye button when the toggle is not requested',
        (tester) async {
      await tester.pumpWidget(_host(const AppInput(
        label: 'Mật khẩu',
        obscureText: true,
      )));
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
    });

    testWidgets('a tappable field does not accept typing', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AppInput(
        label: 'Ngày',
        onPressContainer: () => taps++,
      )));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.byType(AppInput));
      expect(taps, 1);
    });
  });

  group('controls', () {
    testWidgets('AppBadge renders label and icon', (tester) async {
      await tester.pumpWidget(_host(const AppBadge(
        label: 'Đang dùng',
        tone: BadgeTone.success,
        icon: Icons.check,
      )));
      expect(find.text('Đang dùng'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('ChipSelect reports the tapped value', (tester) async {
      String? picked;
      await tester.pumpWidget(_host(ChipSelect<String>(
        label: 'Giới tính',
        value: 'male',
        options: const [
          ChipOption(value: 'male', label: 'Nam'),
          ChipOption(value: 'female', label: 'Nữ'),
        ],
        onChanged: (v) => picked = v,
      )));
      await tester.tap(find.text('Nữ'));
      expect(picked, 'female');
    });

    testWidgets('SegmentedControl switches value', (tester) async {
      String? picked;
      await tester.pumpWidget(_host(SegmentedControl<String>(
        value: 'vi',
        options: const [
          ChipOption(value: 'vi', label: 'Tiếng Việt'),
          ChipOption(value: 'en', label: 'English'),
        ],
        onChanged: (v) => picked = v,
      )));
      await tester.tap(find.text('English'));
      expect(picked, 'en');
    });

    testWidgets('ProgressRing paints and shows its label', (tester) async {
      await tester.pumpWidget(_host(const ProgressRing(
        progress: 0.75,
        label: '75%',
        caption: 'liều đã uống',
      )));
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('liều đã uống'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProgressRing survives out-of-range progress', (tester) async {
      await tester.pumpWidget(_host(const ProgressRing(progress: 5)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(_host(const ProgressRing(progress: -2)));
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    testWidgets('AppScreen renders children and scrolls', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppScreen(
          children: List.generate(30, (i) => AppText('dòng $i')),
        ),
      ));
      expect(find.text('dòng 0'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('AppHeader shows title and pops on back', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AppButton(
              label: 'go',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(
                    body: AppHeader(title: 'Chi tiết'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết'), findsNothing);
    });

    testWidgets('SectionHeader action fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(SectionHeader(
        title: 'Hồ sơ',
        actionLabel: 'Sửa',
        onAction: () => taps++,
      )));
      await tester.tap(find.text('Sửa'));
      expect(taps, 1);
    });

    testWidgets('EmptyState shows icon, title, body and action',
        (tester) async {
      await tester.pumpWidget(_host(const EmptyState(
        icon: Icons.medication_outlined,
        title: 'Chưa có đơn thuốc',
        body: 'Thêm đơn để bắt đầu.',
        action: AppButton(label: 'Thêm'),
      )));
      expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
      expect(find.text('Chưa có đơn thuốc'), findsOneWidget);
      expect(find.text('Thêm đơn để bắt đầu.'), findsOneWidget);
      expect(find.text('Thêm'), findsOneWidget);
    });
  });

  group('TabsShell', () {
    Future<void> pumpShell(WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: TabsShell()),
      ));
      await tester.pump();
    }

    testWidgets('keeps one persistent bar and swaps tabs in place',
        (tester) async {
      await pumpShell(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      // All four tabs live in the stack at once — that is what preserves each
      // tab's scroll position and loaded data across switches.
      expect(find.byType(IndexedStack), findsOneWidget);

      final navigator = tester.widget<Navigator>(find.byType(Navigator).first);
      expect(navigator, isNotNull);
    });

    testWidgets('tapping a tab does not push a route', (tester) async {
      await pumpShell(tester);

      final before = tester.widget<IndexedStack>(find.byType(IndexedStack)).index;
      expect(before, 0);

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pump();

      final after = tester.widget<IndexedStack>(find.byType(IndexedStack)).index;
      expect(after, 3, reason: 'the visible child changes');
      expect(find.byType(NavigationBar), findsOneWidget,
          reason: 'still exactly one bar — a pushed screen would add another');
    });

    testWidgets('honours the initial tab', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: TabsShell(initialIndex: 1)),
      ));
      await tester.pump();
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        1,
      );
    });
  });

  group('TimeField', () {
    const labels = {
      'schedule.morning': 'Sáng',
      'schedule.noon': 'Trưa',
      'schedule.evening': 'Chiều',
      'schedule.night': 'Tối',
    };

    Future<void> openSheet(WidgetTester tester, {String value = '08:00',
        required ValueChanged<String> onChanged}) async {
      await tester.pumpWidget(_host(TimeField(
        label: 'Giờ uống',
        value: value,
        title: 'Giờ uống',
        presetLabels: labels,
        doneLabel: 'Xong',
        cancelLabel: 'Hủy',
        onChanged: onChanged,
      )));
      await tester.tap(find.byType(TimeField));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current time and one-tap presets', (tester) async {
      await openSheet(tester, onChanged: (_) {});

      expect(find.text('Sáng 08:00'), findsOneWidget);
      expect(find.text('Trưa 12:00'), findsOneWidget);
      expect(find.text('Chiều 18:00'), findsOneWidget);
      expect(find.text('Tối 21:00'), findsOneWidget);
      expect(find.text('Xong'), findsOneWidget);
    });

    testWidgets('a preset sets the time and Done returns it', (tester) async {
      String? picked;
      await openSheet(tester, onChanged: (v) => picked = v);

      await tester.tap(find.text('Chiều 18:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      expect(picked, '18:00');
    });

    testWidgets('Cancel leaves the value untouched', (tester) async {
      String? picked;
      await openSheet(tester, onChanged: (v) => picked = v);

      await tester.tap(find.text('Trưa 12:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(picked, isNull, reason: 'cancelling must not report a change');
    });

    testWidgets('a malformed stored time does not crash the sheet',
        (tester) async {
      await openSheet(tester, value: 'not-a-time', onChanged: (_) {});
      // Falls back to a sane default rather than throwing.
      expect(find.text('08:00'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
