import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';
import 'tenant_helpers.dart';

// payment tab that lists rent history and pay button
class TenantPayments extends StatelessWidget {
  final String uid;
  final double rent;
  final VoidCallback onPay;
  const TenantPayments({super.key, required this.uid,
    required this.rent, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final svc = ColdmountService();
    return StreamBuilder<QuerySnapshot>(
      stream: svc.getTenantPayments(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const CmLoading();
        }
        if (snap.hasError) {
          return CmErrorCard(
            title: 'Could not load payments', error: snap.error);
        }
        final docs = ColdmountService.sortByCreatedDesc(snap.data?.docs ?? []);
        final month = monthLabel(DateTime.now());
        final locked = monthLocked(snap.data?.docs ?? [], month);
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (docs.isEmpty)
            const CmCard(child: ListTile(
              leading: Icon(Icons.receipt),
              title: Text('No payments yet'),
              subtitle: Text('Your rent payments will appear here.'))),
          for (final d in docs)
            CmCard(child: Builder(builder: (_) {
              final p = d.data() as Map<String, dynamic>;
              final status = (p['status'] as String?) ?? 'pending';
              final receipt = (p['receipt'] as String?) ?? '';
              final note = (p['note'] as String?) ?? '';
              return Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['month']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${p['method']}',
                      style: const TextStyle(fontSize: 12)),
                    if (note.isNotEmpty)
                      Text(note, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(peso((p['amount'] as num).toDouble()),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                    CmBadge(label: status, kind: status),
                  ]),
                ]),
                if (receipt.isNotEmpty)
                  Align(alignment: Alignment.centerLeft,
                    child: Text('Receipt $receipt',
                      style: const TextStyle(fontSize: 12, color: CmColors.primary))),
              ]);
            })),
          if (locked)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: const CmCard(child: ListTile(
                leading: Icon(Icons.lock, color: Colors.green),
                title: Text('This month is settled'),
                subtitle: Text('Pay re-opens next billing month, or if a payment is rejected.')))),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: locked ? Colors.grey : CmColors.accent,
                foregroundColor: Colors.white),
              onPressed: locked ? null : onPay,
              child: Text(locked ? 'Rent Submitted ✓' : 'Pay Rent Now'))),
        ]);
      });
  }
}

// bottom sheet that collects rent payment in three steps
class PaySheet extends StatefulWidget {
  final double amount;
  final Future<void> Function(String method) onSubmitted;
  const PaySheet({super.key, required this.amount, required this.onSubmitted});
  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  int step = 0; String? method;
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // step that lets tenant choose gcash bank or cash
          if (step == 0) ...[
            const Text('Pay Rent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${peso(widget.amount)} — ${monthLabel(DateTime.now())}'),
            for (final m in ['GCash', 'Bank Transfer', 'Cash'])
              ListTile(title: Text(m),
                subtitle: Text(m == 'Cash'
                  ? 'Hand to caretaker. Admin confirms receipt.'
                  : m == 'GCash' ? 'Send to 0917-000-0001' : 'BPI Account No. 1023-4567-89'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() { method = m; step = 1; })),
          ] else if (step == 1) ...[
            // step that confirms method amount and submits payment
            const Text('Confirm Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Method: $method\nAmount: ${peso(widget.amount)}\nFor: ${monthLabel(DateTime.now())}'),
            if (method == 'Cash')
              const Text('Cash creates a Pending record until admin confirms.',
                style: TextStyle(color: Colors.amber)),
            ElevatedButton(
              // submits payment then advances to success or shows error
              onPressed: isSubmitting ? null : () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => isSubmitting = true);
                try {
                  await widget.onSubmitted(method!);
                  if (mounted) setState(() { isSubmitting = false; step = 2; });
                } catch (e) {
                  if (!mounted) return;
                  setState(() => isSubmitting = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Payment failed: $e')));
                }
              },
              child: Text(isSubmitting
                ? 'Submitting…'
                : method == 'Cash' ? 'Log Cash Payment' : "I've Sent the Payment")),
          ] else ...[
            // final step that shows success and waits verification
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            Text(method == 'Cash' ? 'Cash Payment Logged' : 'Payment Submitted!'),
            const Text('Pending admin verification (within 24h). Receipt follows verification.'),
            ElevatedButton(onPressed: () => Navigator.pop(context),
              child: const Text('Done')),
          ],
        ])),
    );
  }
}
