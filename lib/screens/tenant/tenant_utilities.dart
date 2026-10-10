import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/bill.dart';
import '../../widgets/common.dart';

// utilities tab that lists bills with unpaid total header
class TenantUtilities extends StatelessWidget {
  final List<UtilityBill> bills;
  final void Function(UtilityBill bill) onPayBill;
  const TenantUtilities({super.key, required this.bills,
    required this.onPayBill});

  @override
  Widget build(BuildContext context) {
    final total = bills.where((b) => b.status == 'unpaid')
      .fold<double>(0, (s, b) => s + b.amount);
    return ListView(padding: const EdgeInsets.all(16), children: [
      CmCard(child: Text('Unpaid: ${peso(total)}',
        style: const TextStyle(fontWeight: FontWeight.bold))),
      for (final u in bills)
        CmCard(child: Column(children: [
          Row(children: [
            const Icon(Icons.bolt), const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.type, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(u.detail, style: const TextStyle(fontSize: 12)),
              Text('Due: ${u.due} · ${u.period}', style: const TextStyle(fontSize: 12)),
              if (u.status == 'paid' && u.method.isNotEmpty)
                Text('Paid via ${u.method}',
                  style: const TextStyle(fontSize: 11, color: Colors.green)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(peso(u.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
              CmBadge(label: u.status, kind: u.status),
            ]),
          ]),
          if (u.status == 'unpaid')
            SizedBox(width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onPayBill(u),
                child: const Text('Record Payment',
                  style: TextStyle(fontSize: 12)))),
        ])),
      const CmCard(child: Text(
        'Bills are posted by your admin each month. Recording a payment '
        'saves how you paid (cash to caretaker, GCash, or bank) so both '
        'sides have a paper trail.',
        style: TextStyle(fontSize: 11, color: Colors.grey))),
    ]);
  }
}

// sheet that records how tenant paid a utility bill
class RecordBillSheet extends StatefulWidget {
  final UtilityBill bill;
  final Future<void> Function(String method) onConfirm;
  const RecordBillSheet({super.key, required this.bill,
    required this.onConfirm});
  @override
  State<RecordBillSheet> createState() => _RecordBillSheetState();
}

class _RecordBillSheetState extends State<RecordBillSheet> {
  String method = 'Cash to caretaker';
  bool working = false;
  String error = '';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Pay ${widget.bill.type}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${peso(widget.bill.amount)} · ${widget.bill.period} · Due ${widget.bill.due}',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft,
            child: Text('HOW DID YOU PAY?',
              style: TextStyle(fontSize: 11, color: Colors.grey))),
          for (final m in ['Cash to caretaker', 'GCash', 'Bank transfer'])
            ListTile(
              title: Text(m, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                m == 'Cash to caretaker'
                  ? 'Hand cash directly; caretaker confirms later'
                  : m == 'GCash'
                    ? 'Send to 0917-000-0001 · Coldmount Property'
                    : 'BPI Account No. 1023-4567-89 · Coldmount Property Inc.',
                style: const TextStyle(fontSize: 11)),
              trailing: method == m
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.circle_outlined, color: Colors.grey),
              onTap: () => setState(() => method = m),
              dense: true),
          if (method != 'Cash to caretaker')
            const Text('Keep your transfer reference — the admin may ask for it.',
              style: TextStyle(fontSize: 11, color: Colors.amber)),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CmColors.accent, foregroundColor: Colors.white),
              // saves payment method then closes sheet with confirmation snackbar
              onPressed: working ? null : () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                setState(() { working = true; error = ''; });
                try {
                  await widget.onConfirm(method);
                  navigator.pop();
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                      '${widget.bill.type} recorded as paid via $method')));
                } catch (e) {
                  if (!mounted) return;
                  setState(() { working = false; error = 'Save failed: $e'; });
                }
              },
              child: Text(working ? 'Saving…' : "I've Paid — Record It"))),
        ])),
    );
  }
}
