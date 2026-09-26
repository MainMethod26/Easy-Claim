import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easyclaim/core/theme/ec_status_colors.dart';
import 'package:easyclaim/core/theme/ec_theme.dart';
import 'package:easyclaim/core/widgets/admin/ec_admin_shell.dart';
import 'package:easyclaim/core/widgets/admin/ec_charts.dart';
import 'package:easyclaim/core/widgets/admin/ec_confirm_dialog.dart';
import 'package:easyclaim/core/widgets/admin/ec_data_table.dart';
import 'package:easyclaim/core/widgets/admin/ec_kpi_card.dart';
import 'package:easyclaim/core/widgets/admin/ec_section.dart';
import 'package:easyclaim/core/widgets/admin/ec_status_chip.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light, Size size = const Size(1400, 900)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: brightness == Brightness.light ? EcTheme.light(useGoogleFonts: false) : EcTheme.dark(useGoogleFonts: false),
      home: Scaffold(body: child),
    ),
  );
}

const _destinations = [
  EcNavItem(label: 'Overview', icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard),
  EcNavItem(label: 'Team', icon: Icons.group_outlined, selectedIcon: Icons.group),
  EcNavItem(label: 'Audit log', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long),
];

Widget _shell(Size size) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: EcTheme.light(useGoogleFonts: false),
        home: EcAdminShell(
          productTitle: 'EasyClaim',
          scopeLabel: 'Discovery Health',
          scopeIcon: Icons.apartment_outlined,
          destinations: _destinations,
          selectedIndex: 0,
          onSelect: (_) {},
          pageTitle: 'Overview',
          userName: 'Discovery Admin',
          userRole: 'INSURER_ADMIN',
          body: const Text('page body'),
        ),
      ),
    );

void main() {
  group('theme', () {
    test('light and dark themes carry the semantic status extension', () {
      expect(EcTheme.light(useGoogleFonts: false).extension<EcStatusColors>(), EcStatusColors.light);
      expect(EcTheme.dark(useGoogleFonts: false).extension<EcStatusColors>(), EcStatusColors.dark);
    });

    test('status foregrounds meet 4.5:1 contrast on their backgrounds (light and dark)', () {
      double lum(Color c) => c.computeLuminance();
      double ratio(Color a, Color b) {
        final l1 = lum(a), l2 = lum(b);
        return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
      }

      for (final palette in [EcStatusColors.light, EcStatusColors.dark]) {
        for (final tone in [palette.neutral, palette.info, palette.success, palette.warning, palette.danger]) {
          expect(ratio(tone.foreground, tone.background), greaterThanOrEqualTo(4.5));
        }
      }
    });
  });

  group('status chips always pair an icon with a text label', () {
    testWidgets('integrity, band, stage, outcome and account chips', (tester) async {
      await tester.pumpWidget(_wrap(Wrap(children: [
        EcStatusChip.integrity('VALID'),
        EcStatusChip.integrity('TAMPERED'),
        EcStatusChip.band('HIGH'),
        EcStatusChip.stage('Review'),
        EcStatusChip.outcome('denied'),
        EcStatusChip.account('disabled'),
      ])));
      for (final label in ['Verified', 'Tampered', 'High', 'Review', 'Denied', 'Disabled']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(Icon), findsNWidgets(6));
    });
  });

  group('shell adapts to window size (M3 breakpoints)', () {
    testWidgets('compact: drawer, no rail', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_shell(const Size(400, 800)));
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('Discovery Health'), findsOneWidget);
    });

    testWidgets('medium: collapsed rail', (tester) async {
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_shell(const Size(900, 800)));
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
    });

    testWidgets('expanded: extended sidebar with brand', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_shell(const Size(1400, 900)));
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(find.text('EasyClaim'), findsOneWidget);
      expect(find.text('page body'), findsOneWidget);
    });
  });

  group('data display', () {
    testWidgets('KPI grid, cards and table with empty / loading / error states', (tester) async {
      await tester.pumpWidget(_wrap(SingleChildScrollView(
        child: Column(children: [
          const EcKpiGrid(children: [
            EcKpiCard(label: 'Open claims', value: '12', caption: 'Submitted → Decision, this insurer'),
            EcKpiCard(label: 'Approval rate', value: '75%', caption: 'Approved ÷ decided, last 30 days'),
          ]),
          EcSection(
            title: 'Accounts',
            child: EcDataTable<Map<String, String>>(
              columns: [
                EcColumn(label: 'User', cell: (r) => Text(r['user']!)),
                EcColumn(label: 'Status', cell: (r) => EcStatusChip.account(r['status']!)),
              ],
              rows: const [
                {'user': 'assessor_a1', 'status': 'active'},
              ],
            ),
          ),
          const EcDataTable<int>(columns: [], rows: [], emptyTitle: 'No audit events'),
          const EcDataTable<int>(columns: [], rows: [], loading: true),
          const EcDataTable<int>(columns: [], rows: [], error: 'Network error'),
          const EcIdText('dec_67d21931-8cf6-47df-8dd7-f39125aea426'),
        ]),
      )));
      expect(find.text('Open claims'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('assessor_a1'), findsOneWidget);
      expect(find.text('No audit events'), findsOneWidget);
      expect(find.text('Could not load'), findsOneWidget);
      expect(find.textContaining('…'), findsOneWidget);
    });

    testWidgets('bar chart and proportion bar render labelled values', (tester) async {
      await tester.pumpWidget(_wrap(Column(children: [
        const EcBarChart(data: [EcBarDatum('Submitted', 3), EcBarDatum('Review', 5)]),
        EcProportionBar(segments: [
          (label: 'Normal', value: 8, color: Colors.green, icon: Icons.check_circle_outline),
          (label: 'High', value: 2, color: Colors.red, icon: Icons.warning_amber_rounded),
        ]),
      ])));
      await tester.pumpAndSettle();
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('8 (80%)'), findsOneWidget);
      expect(find.text('2 (20%)'), findsOneWidget);
    });
  });

  testWidgets('sensitive action needs a reason before it can be confirmed', (tester) async {
    String? result = 'untouched';
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => FilledButton(
        onPressed: () async {
          result = await showEcConfirmWithReason(context, title: 'Disable account', message: 'They lose access immediately.', confirmLabel: 'Disable', destructive: true);
        },
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Disable');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Left the company');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, 'Left the company');
  });
}
