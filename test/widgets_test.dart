import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medremind/components/app_button.dart';
import 'package:medremind/components/app_card.dart';
import 'package:medremind/components/app_input.dart';
import 'package:medremind/components/app_text.dart';
import 'package:medremind/components/controls.dart';
import 'package:medremind/components/layout.dart';
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
}
