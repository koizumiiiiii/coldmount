import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/mock_data.dart';
import '../../models/bill.dart';
import '../../services/auth_service.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/common.dart';
import 'tenant_helpers.dart';
import 'tenant_home.dart';
import 'tenant_lease.dart';
import 'tenant_maintenance.dart';
import 'tenant_notifications.dart';
import 'tenant_payments.dart';
import 'tenant_profile.dart';
import 'tenant_utilities.dart';

// tenant shell that loads the profile and hosts five tabs
class TenantApp extends StatefulWidget {
  final String uid;
  final VoidCallback onLogout;
  const TenantApp({super.key, required this.uid, required this.onLogout});
  @override
  State<TenantApp> createState() => _TenantAppState();
}

class _TenantAppState extends State<TenantApp> {
  int tab = 0;
  Map<String, dynamic>? profile;
  bool loadingProfile = true;
  String profileError = '';
  List<UtilityBill> bills = List.of(utilitiesData);
  final _svc = ColdmountService();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // loads tenant profile from firestore and handles missing errors
  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() { loadingProfile = true; profileError = ''; });
    try {
      final p = await AuthService().fetchProfile(widget.uid);
      if (!mounted) return;
      setState(() {
        profile = p;
        loadingProfile = false;
        if (p == null) profileError = 'Profile not found. Ask your admin.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingProfile = false;
        profileError = 'Could not load profile. Check connection.';
      });
    }
  }

  String get _name => (profile?['name'] as String?) ?? '';
  String get _unit => (profile?['unit'] as String?) ?? '';
  String? get _photo => profile?['photo_url'] as String?;

  // opens rent payment sheet for the current billing month
  void openPay(double amount) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => PaySheet(
      amount: amount,
      onSubmitted: (method) async {
        await _svc.submitRentPayment(
          uid: widget.uid, tenantName: _name, unit: _unit,
          month: monthLabel(DateTime.now()), amount: amount, method: method);
      }));

  // opens maintenance request sheet for reporting unit issues
  void openRequest() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => RequestSheet(
      uid: widget.uid, tenantName: _name, unit: _unit));

  // opens notifications panel showing violations refunds and announcements
  void openNotif() => showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => NotificationsPanel(uid: widget.uid));

  // opens profile sheet then reloads data after it closes
  void openProfile() {
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => TenantProfileSheet(
        profile: profile ?? {},
        onLogout: () {
          navigator.pop();
          widget.onLogout();
        },
        onPhotoChanged: _loadProfile,
        uid: widget.uid,
      )).then((_) => _loadProfile());
  }

  // opens utility bill sheet then marks bill paid locally
  void _payBill(UtilityBill bill) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    builder: (_) => RecordBillSheet(
      bill: bill,
      onConfirm: (method) async {
        await _svc.recordUtilityPayment(
          uid: widget.uid, tenant: _name, unit: _unit,
          billType: bill.type, period: bill.period,
          amount: bill.amount, method: method);
        if (mounted) {
          setState(() {
            bills = bills.map((x) => x.id == bill.id
              ? x.copyWith(status: 'paid', method: method) : x).toList();
          });
        }
      }));

  @override
  Widget build(BuildContext context) {
    if (loadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (profileError.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ]),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.person_off, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(profileError, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadProfile, child: const Text('Retry')),
        ])),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.getTenantLease(widget.uid),
      builder: (context, leaseSnap) {
        final leaseDoc = (leaseSnap.hasData && leaseSnap.data!.docs.isNotEmpty)
          ? leaseSnap.data!.docs.first : null;
        final lease = leaseDoc?.data() as Map<String, dynamic>?;
        final leaseError = leaseSnap.hasError && leaseDoc == null;
        final rent = (lease?['rent'] as num?)?.toDouble() ?? 5500.0;
        final pages = [
          TenantHome(uid: widget.uid, rent: rent, lease: lease,
            tenantName: _name, unit: _unit, bills: bills,
            onPay: () => openPay(rent)),
          TenantLease(uid: widget.uid, leaseId: leaseDoc?.id,
            lease: lease, leaseError: leaseError,
            tenantName: _name, tenantUnit: _unit),
          TenantPayments(uid: widget.uid, rent: rent,
            onPay: () => openPay(rent)),
          TenantUtilities(bills: bills, onPayBill: _payBill),
          TenantMaintenance(uid: widget.uid, onNewRequest: openRequest),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text('$_name · Unit $_unit'),
            actions: [
              Stack(children: [
                IconButton(icon: const Icon(Icons.notifications), onPressed: openNotif),
                Positioned(right: 10, top: 10,
                  child: Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: CmColors.accent, shape: BoxShape.circle))),
              ]),
              GestureDetector(onTap: openProfile,
                child: Padding(padding: const EdgeInsets.only(right: 12),
                  child: _photo != null && _photo!.isNotEmpty
                    ? CircleAvatar(radius: 16,
                        backgroundImage: NetworkImage(_photo!))
                    : Avatar(name: _name.isEmpty ? '?' : _name, size: 32))),
            ],
          ),
          body: pages[tab],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: tab, type: BottomNavigationBarType.fixed,
            selectedItemColor: CmColors.primary,
            onTap: (i) => setState(() => tab = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Lease'),
              BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'Payments'),
              BottomNavigationBarItem(icon: Icon(Icons.bolt), label: 'Utilities'),
              BottomNavigationBarItem(icon: Icon(Icons.build), label: 'Requests'),
            ],
          ),
        );
      });
  }
}
