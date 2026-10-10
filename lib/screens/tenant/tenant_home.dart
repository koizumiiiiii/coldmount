import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/common.dart';
import 'tenant_helpers.dart';

// home tab that shows rent due lease progress and bills
class TenantHome extends StatelessWidget {
  final String uid;
  final double rent;
  final Map<String, dynamic>? lease;
  final String tenantName;
  final String unit;
  final List<dynamic> bills;
  final VoidCallback onPay;
  const TenantHome({super.key, required this.uid, required this.rent,
    required this.lease, required this.tenantName, required this.unit,
    required this.bills, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final svc = ColdmountService();
    final unpaid = bills.where((b) => b.status == 'unpaid').toList();
    final total = unpaid.fold<double>(0, (s, b) => s + (b.amount as double));
    final month = monthLabel(DateTime.now());
    return ListView(padding: const EdgeInsets.all(16), children: [
      // watches payments to lock rent button after submission
      StreamBuilder<QuerySnapshot>(
        stream: svc.getTenantPayments(uid),
        builder: (context, snap) {
          final locked = snap.hasData &&
            monthLocked(snap.data!.docs, month);
          final pendingCount = snap.hasData
            ? snap.data!.docs.where((d) {
                final m = d.data() as Map<String, dynamic>;
                return (m['month'] as String?) == month &&
                  (m['status'] as String?) == 'pending';
              }).length
            : 0;
          return CmCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('RENT DUE', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text(peso(rent),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            Text(lease == null
              ? 'No active lease — contact your admin'
              : '$month · Unit $unit'),
            if (locked)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8)),
                child: Text(
                  pendingCount > 0
                    ? 'Rent for $month submitted — awaiting admin verification.'
                    : 'Rent for $month is paid. Thank you!',
                  style: const TextStyle(fontSize: 12, color: Colors.green)),
              ),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: locked ? Colors.grey : CmColors.accent,
                  foregroundColor: Colors.white),
                onPressed: (locked || lease == null) ? null : onPay,
                child: Text(locked ? 'Rent Submitted ✓' : 'Pay Rent Now'))),
          ]));
        }),
      if (lease != null)
        CmCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('LEASE PROGRESS'), Text(leaseProgressLabel(lease!))]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: leaseProgress(lease!),
            minHeight: 8),
          const SizedBox(height: 4),
          Text('${lease!['start'] ?? ''} — Ends ${lease!['end'] ?? ''}',
            style: const TextStyle(fontSize: 12)),
        ])),
      CmCard(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('UNPAID BILLS'),
            Text(peso(total), style: const TextStyle(fontWeight: FontWeight.w900))]),
        for (final u in unpaid)
          ListTile(dense: true, title: Text(u.type), trailing: Text(peso(u.amount))),
      ])),
      const SectionLabel(label: 'Announcements'),
      StreamBuilder<QuerySnapshot>(
        stream: svc.getAnnouncements(limit: 2),
        builder: (context, snap) {
          if (snap.hasError) {
            return CmCard(child: ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text('Could not load announcements',
                style: TextStyle(color: Colors.red, fontSize: 12)),
              subtitle: Text('${snap.error}',
                style: const TextStyle(fontSize: 11)),
              dense: true));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const CmCard(child: ListTile(
              leading: Icon(Icons.campaign),
              title: Text('No announcements',
                style: TextStyle(color: Colors.grey))));
          }
          return Column(children: [
            for (final d in docs)
              Builder(builder: (_) {
                final a = d.data() as Map<String, dynamic>;
                final warning = (a['type'] as String?) == 'warning';
                return CmCard(child: ListTile(
                  leading: Icon(warning ? Icons.warning : Icons.campaign),
                  title: Text('${a['title'] ?? ''}'),
                  subtitle: Text('${a['body'] ?? ''}')));
              }),
          ]);
        }),
      CmCard(child: Row(children: [
        Expanded(child: depBox('Advance', (lease?['advance'] as num?)?.toDouble() ?? rent * 2, '2 months')),
        const SizedBox(width: 8),
        Expanded(child: depBox('Security', (lease?['security'] as num?)?.toDouble() ?? rent, '1 month')),
      ])),
    ]);
  }
}
