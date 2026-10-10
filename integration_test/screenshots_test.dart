// End-to-end screenshot run for the Chapter VI figures.
// Real Firebase Auth + Firestore on a real Android emulator build.
// Admin password comes from --dart-define=ADMIN_PASS (never committed).
// Leaves (near-)zero residue: all shot docs are deleted at the end and
// the shot tenant profile is released; its Auth row can be removed in
// console if desired.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coldmount/main.dart' as app;
import 'package:coldmount/services/coldmount_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const adminEmail = 'mendozajames992@gmail.com';
const adminPass = String.fromEnvironment('ADMIN_PASS');
const shotName = 'Shot Tenant';
const shotEmail = 'shot.tenant@coldmount.ph';
const shotPhone = '+63 900 000 0001';
const shotOcc = 'Tester';
const shotNotice = 'Shot Test Notice';

Future<void> shot(
    IntegrationTestWidgetsFlutterBinding binding, String name) async {
  await binding.convertFlutterSurfaceToImage();
  await binding.takeScreenshot(name);
}

Future<void> loginAs(
    WidgetTester tester, String email, String pass) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), pass);
  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle(const Duration(seconds: 8));
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  assert(adminPass.isNotEmpty, 'Pass --dart-define=ADMIN_PASS=...');

  testWidgets('coldmount chapter-6 screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));
    final svc = ColdmountService();

    // 01 — login
    await shot(binding, '01_login');

    // ---- admin session 1 ----
    await loginAs(tester, adminEmail, adminPass);
    expect(find.text('Coldmount Admin'), findsOneWidget);

    // ensure a vacant unit exists for the shot tenant
    var unitsSnap = await svc.getUnits().first;
    var vacantNo = '';
    for (final d in unitsSnap.docs) {
      final m = d.data() as Map<String, dynamic>;
      if ((m['status'] as String?) != 'occupied') {
        vacantNo = (m['unitNo'] as String?) ?? '';
        if (vacantNo.isNotEmpty) break;
      }
    }
    String? extraUnitId;
    if (vacantNo.isEmpty) {
      final ref = await FirebaseFirestore.instance.collection('units').add({
        'unitNo': '209', 'floor': 2, 'rent': 5500.0, 'sqm': 24,
        'status': 'vacant', 'tenant': '', 'tenantUid': '',
        'image_url': null, 'createdAt': Timestamp.now(),
      });
      extraUnitId = ref.id;
      vacantNo = '209';
    }

    // 02 — dashboard (pre-activity)
    await shot(binding, '02_admin_dashboard');

    // ---- create tenant via UI ----
    await tapTab(tester, 'Tenants');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '03_create_tenant_form');
    await tester.enterText(find.byType(TextField).at(0), shotName);
    await tester.enterText(find.byType(TextField).at(1), shotPhone);
    await tester.enterText(find.byType(TextField).at(2), shotEmail);
    await tester.enterText(find.byType(TextField).at(3), shotOcc);
    // first vacant-unit chip = ChoiceChip index 2 (0,1 are role chips)
    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pump();
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    // read the generated temp password off the done screen
    String tempPass = '';
    for (final e in find.textContaining('CM').evaluate()) {
      final w = e.widget;
      if (w is Text && (w.data ?? '').length == 8) {
        tempPass = w.data!;
        break;
      }
    }
    expect(tempPass.isNotEmpty, isTrue);
    await shot(binding, '04_tenant_created');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '05_tenants_roster');

    // ---- create lease via UI ----
    await tapTab(tester, 'Leases');
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '06_create_lease_form');
    await tester.tap(find.textContaining(shotName).first);
    await tester.pump();
    await tester.tap(find.text('Generate Lease Agreement'));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // ---- post announcement via UI ----
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Announcements'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.enterText(find.byType(TextField).at(0), shotNotice);
    await tester.enterText(find.byType(TextField).at(1),
        'Shot notice body for screenshots.');
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '07_announcements_admin');

    // ---- logout admin, login as tenant ----
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await loginAs(tester, shotEmail, tempPass);
    expect(find.textContaining('Shot Tenant'), findsWidgets);

    // 08 — tenant home (rent due + announcement visible)
    await shot(binding, '08_tenant_home');

    // 09 — lease tab
    await tapTab(tester, 'Lease');
    await shot(binding, '09_tenant_lease');

    // 10 — payments tab (empty), then pay flow
    await tapTab(tester, 'Payments');
    await shot(binding, '10_payments_empty');
    await tester.tap(find.text('Pay Rent Now'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shot(binding, '11_pay_choose');
    await tester.tap(find.text('GCash'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shot(binding, '12_pay_confirm');
    await tester.tap(find.text("I've Sent the Payment"));
    await tester.pumpAndSettle(const Duration(seconds: 8));
    await shot(binding, '13_pay_done');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '14_payments_pending_locked');

    // 15 — utilities + record sheet
    await tapTab(tester, 'Utilities');
    await shot(binding, '15_utilities');
    await tester.tap(find.text('Record Payment').first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shot(binding, '16_utility_record_sheet');
    await tester.tap(find.text('GCash'));
    await tester.pump();
    await tester.tap(find.text("I've Paid — Record It"));
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // 17 — maintenance: submit then list
    await tapTab(tester, 'Requests');
    await tester.tap(find.text('New Request'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shot(binding, '17_submit_sheet');
    await tester.enterText(find.byType(TextField).at(0), 'Shot leaking faucet');
    await tester.enterText(
        find.byType(TextField).at(1), 'Drips at night for screenshots.');
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle(const Duration(seconds: 8));
    await shot(binding, '18_maintenance_list');

    // 19 — notifications (empty state)
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await shot(binding, '19_notifications_empty');
    await tester.fling(
        find.text('Notifications'), const Offset(0, 500), 1000);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 20 — profile
    await tester.tap(find.byType(CircleAvatar).first);
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await shot(binding, '20_tenant_profile');

    // tenant logout via profile Sign Out (covers the sheet-dismiss fix)
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle(const Duration(seconds: 6));
    expect(find.text('Sign In'), findsOneWidget);

    // ---- admin session 2: triage everything ----
    await loginAs(tester, adminEmail, adminPass);
    await shot(binding, '21_admin_dashboard_live');

    // units grid + detail attempt
    await tapTab(tester, 'Units');
    await shot(binding, '22_units_grid');
    final unitCard = find.textContaining(RegExp(r'^Unit \d+'));
    if (unitCard.evaluate().isNotEmpty) {
      await tester.tap(unitCard.first);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await shot(binding, '23_unit_detail');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle(const Duration(seconds: 4));
    }

    // payments queue + review sheet + confirm
    await tapTab(tester, 'Payments');
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await shot(binding, '24_payments_queue');
    if (find.text('Review & Verify').evaluate().isNotEmpty) {
      await tester.tap(find.text('Review & Verify').first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await shot(binding, '25_verify_sheet');
      await tester.tap(find.text('Confirm Verify'));
      await tester.pumpAndSettle(const Duration(seconds: 8));
    }

    // maintenance queue: start progress (leave one open state shot first)
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Maintenance'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '26_maintenance_queue');
    if (find.text('Start Progress').evaluate().isNotEmpty) {
      await tester.tap(find.text('Start Progress').first);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await shot(binding, '27_ticket_in_progress');
    }

    // deposits → refund form (fill only, do not save)
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Deposits'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '28_deposits_list');
    if (find.textContaining(shotName).evaluate().isNotEmpty) {
      await tester.tap(find.textContaining(shotName).first);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await shot(binding, '29_refund_form');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // violations: log one (cleaned up at the end)
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(find.text('Violations'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await shot(binding, '30_violations_list');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    await shot(binding, '31_log_violation_form');

    // ---- cleanup: erase shot data ----
    // find shot uid
    final usersQ = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: shotEmail)
        .limit(1)
        .get();
    if (usersQ.docs.isNotEmpty) {
      final shotUid = usersQ.docs.first.id;
      for (final col in [
        'payments', 'tickets', 'leases', 'violations', 'refunds',
        'utility_payments'
      ]) {
        final q = await FirebaseFirestore.instance
            .collection(col)
            .where('uid', isEqualTo: shotUid)
            .get();
        for (final doc in q.docs) {
          await doc.reference.delete();
        }
      }
      final annQ = await FirebaseFirestore.instance
          .collection('announcements')
          .where('title', isEqualTo: shotNotice)
          .get();
      for (final doc in annQ.docs) {
        await doc.reference.delete();
      }
      await svc.removeTenant(uid: shotUid, unitNo: vacantNo);
    }
    if (extraUnitId != null) {
      await FirebaseFirestore.instance
          .collection('units')
          .doc(extraUnitId)
          .delete();
    }
  });
}
