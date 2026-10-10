import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// pending payments queue that streams submissions awaiting verification
class AdminPayments extends StatefulWidget {
  const AdminPayments({super.key});
  @override
  State<AdminPayments> createState() => _AdminPaymentsState();
}

// payments state that tracks verifying sheets in progress
class _AdminPaymentsState extends State<AdminPayments> {
  final _svc = ColdmountService();
  final Set<String> _verifying = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.getPendingPayments(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const CmLoading();
        }
        if (snap.hasError) {
          return CmErrorCard(
            title: 'Could not load pending payments', error: snap.error);
        }
        final pending =
          ColdmountService.sortByCreatedDesc(snap.data?.docs ?? []);
        return ListView(padding: const EdgeInsets.all(16), children: [
          const SectionLabel(label: 'Pending verification'),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context, isScrollControlled: true,
                builder: (_) => const RecordPaymentSheet()),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Record Payment (cash on hand / backfill)',
                style: TextStyle(fontSize: 12)))),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const CmCard(child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('All caught up!'),
              subtitle: Text('No payments pending verification.'))),
          for (final d in pending)
            Builder(builder: (_) {
              final p = d.data() as Map<String, dynamic>;
              final busy = _verifying.contains(d.id);
              return CmCard(child: Column(children: [
                ListTile(
                  leading: Avatar(name: '${p['tenant'] ?? '?'}'),
                  title: Text('${p['tenant'] ?? ''}'),
                  subtitle: Text('Unit ${p['unit'] ?? ''} · ${p['month'] ?? ''} · ${p['method'] ?? ''}'),
                  trailing: Text(peso((p['amount'] as num?)?.toDouble() ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w900))),
                Row(children: [
                  Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: busy ? null : () async {
                      setState(() => _verifying.add(d.id));
                      try {
                        await showModalBottomSheet<void>(
                          context: context, isScrollControlled: true,
                          builder: (_) => VerifySheet(
                            docId: d.id, payment: p));
                      } finally {
                        if (mounted) setState(() => _verifying.remove(d.id));
                      }
                    },
                    child: Text(busy ? 'Reviewing…' : 'Review & Verify',
                      style: const TextStyle(fontSize: 12, color: Colors.white)))),
                ]),
              ]));
            }),
        ]);
      });
  }
}

// record payment sheet that logs cash and backfills past months
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key});
  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

// record state that selects tenant month method and amount
class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  String? tenantUid;
  String tenantName = '';
  String tenantUnit = '';
  int monthsAgo = 0;
  String method = 'Cash';
  final amountCtrl = TextEditingController();
  bool isSaving = false;
  String error = '';

  @override
  void initState() {
    super.initState();
    amountCtrl.text = '5500';
  }

  @override
  Widget build(BuildContext context) {
    final period = billingMonth(monthsAgo: monthsAgo);
    final amount = double.tryParse(amountCtrl.text) ?? 0;
    final valid = tenantUid != null && amount > 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Record Payment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          FutureBuilder<QuerySnapshot>(
            future: ColdmountService().getTenants().first,
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No tenant accounts yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey));
              }
              return Column(children: [
                for (final d in docs)
                  Builder(builder: (_) {
                    final t = d.data() as Map<String, dynamic>;
                    final name = '${t['name'] ?? t['email']}';
                    final selected = tenantUid == d.id;
                    return ListTile(
                      title: Text('$name · Unit ${t['unit'] ?? '?'}'),
                      trailing: selected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.circle_outlined, color: Colors.grey),
                      onTap: () => setState(() {
                        tenantUid = d.id;
                        tenantName = name;
                        tenantUnit = '${t['unit'] ?? ''}';
                      }),
                      dense: true);
                  }),
              ]);
            }),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft,
            child: Text('FOR MONTH',
              style: TextStyle(fontSize: 11, color: Colors.grey))),
          Wrap(spacing: 6, children: [
            for (var i = 0; i < 6; i++)
              ChoiceChip(
                label: Text(
                  '${billingMonth(monthsAgo: i)['short']} ${billingMonth(monthsAgo: i)['year']}',
                  style: const TextStyle(fontSize: 11)),
                selected: monthsAgo == i,
                onSelected: (_) => setState(() => monthsAgo = i)),
          ]),
          Row(children: [
            Expanded(child: TextField(controller: amountCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Amount (₱)'))),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('METHOD',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
              for (final m in ['Cash', 'GCash', 'Bank transfer'])
                GestureDetector(
                  onTap: () => setState(() => method = m),
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Icon(method == m
                        ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: method == m ? Colors.green : Colors.grey),
                      const SizedBox(width: 4),
                      Text(m, style: const TextStyle(fontSize: 12)),
                    ]))),
            ])),
          ]),
          Text('Receipt ${genReceiptNo(DateTime.now().millisecond % 1000)} will be issued',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
              // saves verified payment with receipt number and closes sheet
              onPressed: (!valid || isSaving) ? null : () async {
                final navigator = Navigator.of(context);
                setState(() { isSaving = true; error = ''; });
                try {
                  await ColdmountService().recordPayment(
                    uid: tenantUid!,
                    tenant: tenantName,
                    unit: tenantUnit,
                    month: period['label'] as String,
                    year: period['year'] as int,
                    monthIndex: period['monthIndex'] as int,
                    amount: amount,
                    method: method,
                    receipt: genReceiptNo(
                      DateTime.now().millisecond % 1000),
                  );
                  navigator.pop();
                } catch (e) {
                  if (!mounted) return;
                  setState(() { isSaving = false; error = 'Save failed: $e'; });
                }
              },
              child: Text(isSaving ? 'Saving…' : 'Record as Verified'))),
        ])),
    );
  }
}

// verify sheet that confirms receipt or rejects with reason
class VerifySheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> payment;
  const VerifySheet({super.key, required this.docId, required this.payment});
  @override
  State<VerifySheet> createState() => _VerifySheetState();
}

// verify state that toggles reject mode and tracks progress
class _VerifySheetState extends State<VerifySheet> {
  bool modeReject = false;
  final reasonCtrl = TextEditingController();
  bool working = false;
  String error = '';
  late final String receiptPreview =
    genReceiptNo(DateTime.now().millisecond % 1000);

  // confirms payment verification and issues receipt to history
  Future<void> _confirm() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() { working = true; error = ''; });
    try {
      final per = paymentPeriod(widget.payment);
      await ColdmountService().verifyPaymentDoc(
        widget.docId, receiptPreview,
        year: per['year'], monthIndex: per['month']);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Verified — receipt issued to tenant history')));
    } catch (e) {
      if (!mounted) return;
      setState(() { working = false; error = 'Verify failed: $e'; });
    }
  }

  // rejects payment with reason so tenant knows what to fix
  Future<void> _reject() async {
    if (reasonCtrl.text.trim().isEmpty) {
      setState(() => error = 'Give a reason so the tenant knows what to fix.');
      return;
    }
    final navigator = Navigator.of(context);
    setState(() { working = true; error = ''; });
    try {
      await ColdmountService()
        .rejectPaymentDoc(widget.docId, reasonCtrl.text.trim());
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() { working = false; error = 'Reject failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(modeReject ? 'Reject Payment' : 'Review Payment',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CmCard(child: Column(children: [
            ListTile(title: Text('${p['tenant'] ?? ''}'),
              subtitle: Text('Unit ${p['unit'] ?? ''} · ${p['month'] ?? ''}'),
              trailing: Text(peso((p['amount'] as num?)?.toDouble() ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w900)),
              dense: true),
            ListTile(title: Text('${p['method'] ?? ''}'),
              subtitle: const Text('Method — check the actual transfer or cash received before confirming.'),
              dense: true),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: Text(receiptPreview),
              subtitle: const Text('Receipt number to be issued'),
              dense: true),
          ])),
          if (!modeReject) ...[
            const Text(
              'Nothing is recorded until you confirm. Compare the reference against your GCash/bank app or cash on hand.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
            Row(children: [
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: working ? null : _confirm,
                child: Text(working ? 'Verifying…' : 'Confirm Verify',
                  style: const TextStyle(color: Colors.white)))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                onPressed: working
                  ? null : () => setState(() => modeReject = true),
                child: const Text('Reject',
                  style: TextStyle(color: Colors.red)))),
            ]),
          ] else ...[
            TextField(controller: reasonCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Reason (shown in tenant history)',
                helperText: 'e.g. Wrong amount — September rent is ₱5,500')),
            const SizedBox(height: 8),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: working ? null : () => Navigator.pop(context),
                child: const Text('Cancel'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: working ? null : _reject,
                child: Text(working ? 'Saving…' : 'Reject Payment',
                  style: const TextStyle(color: Colors.white)))),
            ]),
          ],
        ])),
    );
  }
}
