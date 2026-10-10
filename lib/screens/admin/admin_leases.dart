import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// leases list that streams agreements and supports ending them
class AdminLeases extends StatefulWidget {
  const AdminLeases({super.key});
  @override
  State<AdminLeases> createState() => _AdminLeasesState();
}

// leases state that tracks working taps for end delete
class _AdminLeasesState extends State<AdminLeases> {
  final _svc = ColdmountService();
  final Set<String> _working = {}; // tracks end and delete taps currently in flight

  // ends active lease after confirmation while keeping history record
  Future<void> _endLease(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End lease'),
        content: const Text(
          'End this lease now? It leaves the tenant\'s active view '
          '(kept as history) so you can create a fresh, correctly-dated one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Lease',
              style: TextStyle(color: Colors.red))),
        ],
      ));
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working.add(id));
    try {
      await _svc.endLease(id);
      messenger.showSnackBar(const SnackBar(
        content: Text('Lease ended — create a new one with correct dates')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _working.remove(id));
    }
  }

  // deletes lease record permanently after background service call
  Future<void> _deleteLease(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working.add(id));
    try {
      await _svc.deleteLease(id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Lease record deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => _working.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _svc.getAllLeases(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const CmLoading();
        }
        if (snap.hasError) {
          return CmErrorCard(
            title: 'Could not load leases', error: snap.error);
        }
        final docs = snap.data?.docs ?? [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Lease Records',
              style: TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () async {
                final ok = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateLeaseScreen()));
                if (ok == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lease created')));
                }
              },
              icon: const Icon(Icons.add, size: 16), label: const Text('New')),
          ]),
          const SizedBox(height: 8),
          if (docs.isEmpty)
            const CmCard(child: ListTile(
              leading: Icon(Icons.description),
              title: Text('No leases yet'),
              subtitle: Text('Tap New to generate the first lease agreement.'))),
          for (final d in docs)
            Builder(builder: (_) {
              final l = d.data() as Map<String, dynamic>;
              final status = (l['status'] as String?) ?? 'active';
              return CmCard(child: Column(children: [
                ListTile(
                  leading: Avatar(name: '${l['tenant'] ?? '?'}', size: 32),
                  title: Text('${l['tenant'] ?? ''}'),
                  subtitle: Text('Unit ${l['unit'] ?? ''}'),
                  trailing: CmBadge(
                    label: status == 'expiring-soon' ? 'Expiring soon' : 'Active',
                    kind: status)),
              Text('Start ${l['start'] ?? ''} · End ${l['end'] ?? ''} · ${peso((l['rent'] as num?)?.toDouble() ?? 0)}',
                style: const TextStyle(fontSize: 12)),
              Row(children: [
                if (status == 'active' || status == 'expiring-soon')
                  Expanded(child: OutlinedButton(
                    onPressed: _working.contains(d.id)
                      ? null : () => _endLease(d.id),
                    child: Text(_working.contains(d.id) ? '…' : 'End Lease',
                      style: const TextStyle(fontSize: 12)))),
                if (status == 'active' || status == 'expiring-soon')
                  const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: _working.contains(d.id)
                    ? null : () => _deleteLease(d.id),
                  child: Text(_working.contains(d.id) ? '…' : 'Delete',
                    style: const TextStyle(fontSize: 12, color: Colors.red)))),
              ]),
                if (status == 'expiring-soon')
                  SizedBox(width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CmColors.accent, foregroundColor: Colors.white),
                      onPressed: () async {
                        final approved = await showModalBottomSheet<bool>(
                          context: context, isScrollControlled: true,
                          builder: (_) => RenewalSheet(
                            docId: d.id,
                            tenant: '${l['tenant']}',
                            unit: '${l['unit']}',
                            end: '${l['end']}',
                            rent: ((l['rent'] as num?)?.toDouble() ?? 0)));
                        if (approved == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Renewal approved')));
                        }
                      },
                      child: const Text('Review Renewal (+3% escalation)',
                        style: TextStyle(fontSize: 12)))),
              ]));
            }),
        ]);
      });
  }
}

// parses deposit input text with fallback when invalid number
double _depDouble(String text, double fallback) {
  final v = double.tryParse(text.trim());
  return (v == null || v < 0) ? fallback : v;
}

// create lease form that assigns tenant term and deposits
class CreateLeaseScreen extends StatefulWidget {
  const CreateLeaseScreen({super.key});
  @override
  State<CreateLeaseScreen> createState() => _CreateLeaseScreenState();
}

// create lease state that computes deposits and saves agreement
class _CreateLeaseScreenState extends State<CreateLeaseScreen> {
  String? tenantUid;
  String tenantName = '';
  String tenantUnit = '';
  int months = 12;
  final rentCtrl = TextEditingController(text: '5500');
  final advCtrl = TextEditingController(text: '11000');
  final secCtrl = TextEditingController(text: '5500');
  bool advDirty = false, secDirty = false;
  bool isSaving = false;
  String error = '';

  @override
  Widget build(BuildContext context) {
    final rent = double.tryParse(rentCtrl.text) ?? 0;
    final advDefault = rent * 2;
    final secDefault = rent;
    return Scaffold(
      appBar: AppBar(title: const Text('Create Lease')),
      body: FutureBuilder<QuerySnapshot>(
        future: ColdmountService().getTenants().first,
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView(padding: const EdgeInsets.all(16), children: [
            CmCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionLabel(label: 'Tenant'),
              if (snap.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator()),
              if (docs.isEmpty && snap.connectionState != ConnectionState.waiting)
                const Text('No tenant accounts yet — create one first.'),
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
                      tenantName = '${t['name'] ?? ''}';
                      tenantUnit = '${t['unit'] ?? ''}';
                    }),
                    dense: true);
                }),
            ])),
            CmCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionLabel(label: 'Lease Term'),
              Row(children: [
                for (final m in [6, 12, 24])
                  Expanded(child: Padding(padding: const EdgeInsets.all(4),
                    child: ChoiceChip(label: Text('$m mo'), selected: months == m,
                      onSelected: (_) => setState(() => months = m)))),
              ]),
              TextField(controller: rentCtrl, keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {
                  final r = double.tryParse(rentCtrl.text) ?? 0;
                  if (!advDirty) advCtrl.text = (r * 2).toStringAsFixed(0);
                  if (!secDirty) secCtrl.text = r.toStringAsFixed(0);
                }),
                decoration: const InputDecoration(labelText: 'Monthly Rent (₱)')),
              const SizedBox(height: 8),
              const SectionLabel(label: 'Deposits on hold'),
              TextField(controller: advCtrl, keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => advDirty = true),
                decoration: const InputDecoration(
                  labelText: 'Advance deposit (₱)',
                  helperText: 'Standard: 2 months rent (prepaid, non-refundable)')),
              TextField(controller: secCtrl, keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => secDirty = true),
                decoration: const InputDecoration(
                  labelText: 'Security deposit (₱)',
                  helperText: 'Standard: 1 month rent (refundable safety fund)')),
              const SizedBox(height: 8),
              Text('Total on hold: ${peso(_depDouble(advCtrl.text, advDefault) + _depDouble(secCtrl.text, secDefault))}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ])),
            if (error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CmColors.accent, foregroundColor: Colors.white),
                // saves lease agreement with computed dates and deposit amounts
                onPressed: (tenantUid == null || rent <= 0 || isSaving) ? null : () async {
                  final navigator = Navigator.of(context);
                  setState(() { isSaving = true; error = ''; });
                  try {
                    final now = DateTime.now();
                    final end =
                      DateTime(now.year, now.month + months, now.day);
                    await ColdmountService().createLease({
                      'uid': tenantUid,
                      'tenant': tenantName,
                      'unit': tenantUnit,
                      'start': shortDate(now),
                      'end': shortDate(end),
                      'startTs': now.millisecondsSinceEpoch,
                      'endTs': end.millisecondsSinceEpoch,
                      'rent': rent,
                      'advance': _depDouble(advCtrl.text, advDefault),
                      'security': _depDouble(secCtrl.text, secDefault),
                      'status': 'active',
                      'months': months,
                    });
                    if (mounted) navigator.pop(true);
                  } catch (e) {
                    if (!mounted) return;
                    setState(() { isSaving = false; error = 'Could not create lease: $e'; });
                  }
                },
                child: Text(isSaving ? 'Saving…' : 'Generate Lease Agreement'))),
          ]);
        }),
    );
  }
}

// renewal sheet that picks escalation rate and approves extension
class RenewalSheet extends StatefulWidget {
  final String docId, tenant, unit, end;
  final double rent;
  const RenewalSheet({super.key, required this.docId, required this.tenant,
    required this.unit, required this.end, required this.rent});
  @override
  State<RenewalSheet> createState() => _RenewalSheetState();
}

// renewal state that calculates new rent from escalation percent
class _RenewalSheetState extends State<RenewalSheet> {
  int escalation = 3;
  bool isSaving = false;

  @override
  Widget build(BuildContext context) {
    final newRent = (widget.rent * (1 + escalation / 100)).roundToDouble();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Renewal Approval — ${widget.tenant}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Unit ${widget.unit} · Current end: ${widget.end}'),
          Text('Current rent: ${peso(widget.rent)}'),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft,
            child: Text('RATE INCREASE (%)',
              style: TextStyle(fontSize: 11, color: Colors.grey))),
          Row(children: [
            for (final r in [0, 3, 5, 10])
              Expanded(child: Padding(padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text('$r%'), selected: escalation == r,
                  onSelected: (_) => setState(() => escalation = r)))),
          ]),
          CmCard(child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('New monthly rent'),
            Text(peso(newRent),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
          Row(children: [
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              // approves renewal with new rent and closes sheet
              onPressed: isSaving ? null : () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                setState(() => isSaving = true);
                try {
                  await ColdmountService()
                    .approveRenewalDoc(widget.docId, newRent);
                  navigator.pop(true);
                } catch (e) {
                  if (!mounted) return;
                  setState(() => isSaving = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Approval failed: $e')));
                }
              },
              child: Text(isSaving ? 'Saving…' : 'Approve Renewal',
                style: const TextStyle(color: Colors.white)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Decline',
                style: TextStyle(color: Colors.red)))),
          ]),
        ])),
    );
  }
}
