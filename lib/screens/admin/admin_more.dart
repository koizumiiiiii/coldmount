import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// deposits list that shows tenants for refund calculation flow
class DepositsScreen extends StatelessWidget {
  final VoidCallback onBack;
  const DepositsScreen({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deposits'),
        leading: BackButton(onPressed: onBack)),
      body: StreamBuilder<QuerySnapshot>(
        stream: ColdmountService().getTenants(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CmLoading();
          }
          if (snap.hasError) {
            return CmErrorCard(
              title: 'Could not load tenants', error: snap.error);
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No tenants yet.',
                textAlign: TextAlign.center)));
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final d in docs)
              Builder(builder: (_) {
                final t = d.data() as Map<String, dynamic>;
                final name = (t['name'] as String?) ?? (t['email'] as String?) ?? '';
                final photo = t['photo_url'] as String?;
                return CmCard(child: ListTile(
                  leading: photo != null && photo.isNotEmpty
                    ? CircleAvatar(backgroundImage: NetworkImage(photo))
                    : Avatar(name: name.isEmpty ? '?' : name),
                  title: Text(name.isEmpty ? 'Unnamed tenant' : name),
                  subtitle: Text('Unit ${t['unit'] ?? '?'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RefundScreen(
                        uid: d.id,
                        tenant: name.isEmpty ? 'Tenant' : name,
                        unit: '${t['unit'] ?? ''}'))),
                ));
              }),
          ]);
        }),
    );
  }
}

// refund calculator that subtracts deductions from security deposit
class RefundScreen extends StatefulWidget {
  final String uid, tenant, unit;
  const RefundScreen({super.key, required this.uid,
    required this.tenant, required this.unit});
  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

// refund state that manages deductions list and total refund
class _RefundScreenState extends State<RefundScreen> {
  final descCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final List<Map<String, dynamic>> deductions = [];
  bool isSaving = false;
  String error = '';

  double get deductionsTotal => deductions.fold<double>(
    0, (s, d) => s + ((d['amount'] as num?)?.toDouble() ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Refund — ${widget.tenant}')),
      body: FutureBuilder<QuerySnapshot>(
        future: ColdmountService().getTenantLease(widget.uid).first,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CmLoading();
          }
          if (snap.hasError) {
            return CmErrorCard(
              title: 'Could not load lease', error: snap.error);
          }
          final ldocs = snap.data?.docs ?? [];
          if (ldocs.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No active lease for this tenant — '
                'no security is on hold.',
                textAlign: TextAlign.center)));
          }
          final lease = ldocs.first.data() as Map<String, dynamic>;
          final security =
            ((lease['security'] as num?)?.toDouble() ??
              ((lease['rent'] as num?)?.toDouble() ?? 0));
          final refund = computeRefund(security, deductionsTotal);
          return ListView(padding: const EdgeInsets.all(16), children: [
            CmCard(child: Column(children: [
              const SectionLabel(label: 'Security on hold'),
              Text(peso(security),
                style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w900)),
              Text('Unit ${widget.unit} · refundable within 30 days of move-out',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            const SectionLabel(label: 'Deductions'),
            for (var i = 0; i < deductions.length; i++)
              CmCard(child: ListTile(
                title: Text('${deductions[i]['desc']}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(peso((deductions[i]['amount'] as num).toDouble()),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => setState(() => deductions.removeAt(i))),
                ]),
                dense: true)),
            CmCard(child: Column(children: [
              TextField(controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Deduction (e.g. Wall repaint, unpaid water)')),
              TextField(controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₱)')),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity,
                child: OutlinedButton.icon(
                  // adds deduction entry from description and amount inputs
                  onPressed: () {
                    final amt = double.tryParse(amountCtrl.text) ?? 0;
                    if (descCtrl.text.trim().isEmpty || amt <= 0) return;
                    setState(() {
                      deductions.add({
                        'desc': descCtrl.text.trim(), 'amount': amt});
                      descCtrl.clear();
                      amountCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Deduction'))),
            ])),
            CmCard(child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Security held'),
                Text(peso(security),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Deductions'),
                Text('−${peso(deductionsTotal)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.red)),
              ]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Refundable',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(peso(refund),
                  style: const TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: Colors.green)),
              ]),
            ])),
            if (error.isNotEmpty)
              Text(error,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white),
                // records refund with deductions and updates lease security hold
                onPressed: isSaving ? null : () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() { isSaving = true; error = ''; });
                  try {
                    await ColdmountService().recordRefund(
                      uid: widget.uid, tenant: widget.tenant,
                      unit: widget.unit, security: security,
                      deductions: List.of(deductions), refund: refund);
                    // updates lease security hold to refunded amount after recording
                    final active = await ColdmountService()
                      .getTenantLease(widget.uid).first;
                    for (final doc in active.docs) {
                      await ColdmountService()
                        .updateLeaseDoc(doc.id, {'security': refund});
                    }
                    navigator.pop();
                    messenger.showSnackBar(SnackBar(
                      content: Text(
                        'Refund recorded: ${peso(refund)} — security hold now ${peso(refund)}')));
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      isSaving = false; error = 'Save failed: $e';
                    });
                  }
                },
                child: Text(isSaving ? 'Saving…' : 'Record Refund'))),
          ]);
        }),
    );
  }
}

// violations list that streams logs with severity and delete
class ViolationsScreen extends StatelessWidget {
  final VoidCallback onBack;
  const ViolationsScreen({super.key, required this.onBack});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Violations'),
        leading: BackButton(onPressed: onBack),
        actions: [IconButton(icon: const Icon(Icons.add),
          onPressed: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            builder: (_) => const LogViolationSheet()))]),
      body: StreamBuilder<QuerySnapshot>(
        stream: ColdmountService().getAllViolations(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CmLoading();
          }
          if (snap.hasError) {
            return CmErrorCard(
              title: 'Could not load violations', error: snap.error);
          }
          final docs =
            ColdmountService.sortByCreatedDesc(snap.data?.docs ?? []);
          if (docs.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No violations logged.',
                textAlign: TextAlign.center)));
          }
          String fmtDate(Timestamp? ts) => ts == null ? '' :
            '${ts.toDate().month}/${ts.toDate().day}/${ts.toDate().year}';

          // confirms deletion then removes violation log from firestore
          Future<void> removeLog(
              BuildContext context, String id, String title) async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('delete violation'),
                content: Text('delete "$title"? tenant will no longer see it.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('delete',
                        style: TextStyle(color: Colors.red))),
                ],
              ));
            if (ok != true) return;
            if (!context.mounted) return;
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ColdmountService().deleteViolation(id);
              messenger.showSnackBar(
                  const SnackBar(content: Text('violation deleted')));
            } catch (e) {
              messenger.showSnackBar(
                  SnackBar(content: Text('delete failed: $e')));
            }
          }

          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final d in docs)
              Builder(builder: (_) {
                final v = d.data() as Map<String, dynamic>;
                final severity = (v['severity'] as String?) ?? 'minor';
                return CmCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('${v['title'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                    CmBadge(label: severity, kind: severity),
                    IconButton(
                      icon: const Icon(Icons.delete,
                        color: Colors.red, size: 20),
                      tooltip: 'delete',
                      onPressed: () => removeLog(
                          context, d.id, '${v['title'] ?? ''}')),
                  ]),
                  Text('${v['tenant'] ?? ''} · Unit ${v['unit'] ?? ''} · ${fmtDate(v['date'] as Timestamp?)}'),
                  CmBadge(label: '${v['status'] ?? 'noted'}',
                    kind: '${v['status'] ?? 'noted'}'),
                  Text('${v['notes'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
                ]));
              }),
          ]);
        }),
    );
  }
}

// log violation sheet that assigns tenant severity and notes
class LogViolationSheet extends StatefulWidget {
  const LogViolationSheet({super.key});
  @override
  State<LogViolationSheet> createState() => _LogViolationSheetState();
}

// violation form state that validates title and saves log
class _LogViolationSheetState extends State<LogViolationSheet> {
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  String tenantUid = '';
  String tenant = '';
  String unit = '';
  String severity = 'minor';
  bool isSaving = false;
  String error = '';

  @override
  Widget build(BuildContext context) {
    final valid = titleCtrl.text.isNotEmpty && tenantUid.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Log Violation',
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
                        tenant = name;
                        unit = '${t['unit'] ?? ''}';
                      }),
                      dense: true);
                  }),
              ]);
            }),
          TextField(controller: titleCtrl, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Title')),
          Row(children: [
            for (final s in ['minor', 'major'])
              Expanded(child: Padding(padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(s), selected: severity == s,
                  onSelected: (_) => setState(() => severity = s)))),
          ]),
          TextField(controller: notesCtrl, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 8),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              // saves violation log with tenant severity and notes
              onPressed: (!valid || isSaving) ? null : () async {
                final navigator = Navigator.of(context);
                setState(() { isSaving = true; error = ''; });
                try {
                  await ColdmountService().logViolation(
                    tenantUid: tenantUid, tenant: tenant, unit: unit,
                    title: titleCtrl.text.trim(), severity: severity,
                    notes: notesCtrl.text.trim());
                  navigator.pop();
                } catch (e) {
                  if (!mounted) return;
                  setState(() { isSaving = false; error = 'Save failed: $e'; });
                }
              },
              child: Text(isSaving ? 'Saving…' : 'Save Violation'))),
        ])),
    );
  }
}

// maintenance queue that groups open and resolved tenant tickets
class MaintenanceScreen extends StatefulWidget {
  final VoidCallback onBack;
  const MaintenanceScreen({super.key, required this.onBack});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

// maintenance state that tracks ticket status updates in progress
class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final _svc = ColdmountService();
  final Set<String> _working = {}; // tracks ticket status taps currently in flight

  // updates ticket status to started or resolved with feedback
  Future<void> _setStatus(String id, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _working.add(id));
    try {
      if (action == 'start') {
        await _svc.startTicket(id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Ticket in progress — tenant sees the update')));
      } else {
        await _svc.resolveTicket(id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Ticket resolved')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _working.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance'),
        leading: BackButton(onPressed: widget.onBack)),
      body: StreamBuilder<QuerySnapshot>(
        stream: _svc.getAllTickets(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CmLoading();
          }
          if (snap.hasError) {
            return CmErrorCard(
              title: 'Could not load tickets', error: snap.error);
          }
          final docs =
            ColdmountService.sortByCreatedDesc(snap.data?.docs ?? []);
          bool isOpen(QueryDocumentSnapshot d) {
            final s = ((d.data() as Map<String, dynamic>)['status'] as String?);
            return s == 'submitted' || s == 'in-progress';
          }
          final open = docs.where(isOpen).toList();
          final done = docs.where((d) => !isOpen(d)).toList();
          if (docs.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No maintenance requests.\nTenant submissions appear here.',
                textAlign: TextAlign.center)));
          }
          Widget card(QueryDocumentSnapshot d) {
            final t = d.data() as Map<String, dynamic>;
            final status = (t['status'] as String?) ?? 'submitted';
            final category = (t['category'] as String?) ?? 'minor';
            final photo = (t['photo_url'] as String?) ?? '';
            final assignee = (t['assignee'] as String?) ?? '';
            final busy = _working.contains(d.id);
            return CmCard(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (photo.isNotEmpty)
                Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(photo, height: 140,
                      width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const SizedBox()))),
              Text('${t['title'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${t['tenant'] ?? ''} · Unit ${t['unit'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Wrap(spacing: 6, children: [
                CmBadge(label: category, kind: category),
                CmBadge(label: status.replaceAll('-', ' '), kind: status),
              ]),
              if ((t['description'] as String?)?.isNotEmpty == true)
                Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text('${t['description']}',
                    style: const TextStyle(fontSize: 12))),
              if (assignee.isNotEmpty)
                Text('Assigned to $assignee',
                  style: const TextStyle(fontSize: 12, color: Colors.blue)),
              if (status != 'resolved') ...[
                const SizedBox(height: 8),
                Row(children: [
                  if (status == 'submitted')
                    Expanded(child: OutlinedButton(
                      onPressed: busy ? null : () => _setStatus(d.id, 'start'),
                      child: Text(busy ? '…' : 'Start Progress',
                        style: const TextStyle(fontSize: 12)))),
                  if (status == 'submitted') const SizedBox(width: 8),
                  Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: busy ? null : () => _setStatus(d.id, 'resolve'),
                    child: Text(busy ? '…' : 'Mark Resolved',
                      style: const TextStyle(fontSize: 12, color: Colors.white)))),
                ]),
              ],
            ]));
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (open.isNotEmpty) ...[
              const SectionLabel(label: 'Open'),
              for (final d in open) card(d),
            ],
            if (done.isNotEmpty) ...[
              const SectionLabel(label: 'Resolved'),
              for (final d in done) card(d),
            ],
          ]);
        }),
    );
  }
}

// announcements list that shows posts with delete for tenants
class AnnouncementsScreen extends StatefulWidget {
  final VoidCallback onBack;
  const AnnouncementsScreen({super.key, required this.onBack});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

// announcements state that handles removal of posted updates
class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _svc = ColdmountService();

  // confirms deletion then removes announcement from tenant feed
  Future<void> _removePost(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('delete announcement'),
        content: Text('delete "$title"? tenants will no longer see it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('delete',
                style: TextStyle(color: Colors.red))),
        ],
      ));
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _svc.deleteAnnouncement(id);
      messenger.showSnackBar(
          const SnackBar(content: Text('announcement deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements'),
        leading: BackButton(onPressed: widget.onBack),
        actions: [IconButton(icon: const Icon(Icons.add),
          onPressed: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            builder: (_) => const PostAnnouncementSheet()))]),
      body: StreamBuilder<QuerySnapshot>(
        stream: _svc.getAnnouncements(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const CmLoading();
          }
          if (snap.hasError) {
            return CmErrorCard(
              title: 'Could not load announcements', error: snap.error);
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No announcements yet. Tap + to post one — '
                'it appears on every tenant Home screen.',
                textAlign: TextAlign.center)));
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            for (final d in docs)
              Builder(builder: (_) {
                final a = d.data() as Map<String, dynamic>;
                final ts = a['date'] as Timestamp?;
                final date = ts == null ? '' :
                  '${ts.toDate().month}/${ts.toDate().day}/${ts.toDate().year}';
                return CmCard(child: ListTile(
                  leading: Icon(
                    (a['type'] as String?) == 'warning'
                      ? Icons.warning : Icons.campaign),
                  title: Text('${a['title'] ?? ''}'),
                  subtitle: Text('${a['body'] ?? ''}\n$date'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete,
                      color: Colors.red, size: 20),
                    tooltip: 'delete',
                    onPressed: () =>
                      _removePost(d.id, '${a['title'] ?? ''}')),
                ));
              }),
          ]);
        }),
    );
  }
}

// post announcement sheet that publishes info or warning message
class PostAnnouncementSheet extends StatefulWidget {
  const PostAnnouncementSheet({super.key});
  @override
  State<PostAnnouncementSheet> createState() => _PostAnnouncementSheetState();
}

// post form state that validates title body and type
class _PostAnnouncementSheetState extends State<PostAnnouncementSheet> {
  final titleCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  String type = 'info';
  bool isSaving = false;
  String error = '';

  @override
  Widget build(BuildContext context) {
    final valid = titleCtrl.text.isNotEmpty && bodyCtrl.text.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('New Announcement',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          TextField(controller: titleCtrl, onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: bodyCtrl, maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Message')),
          Row(children: [
            for (final t in ['info', 'warning'])
              Expanded(child: Padding(padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(t), selected: type == t,
                  onSelected: (_) => setState(() => type = t)))),
          ]),
          if (error.isNotEmpty)
            Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CmColors.accent, foregroundColor: Colors.white),
              // posts announcement with title body and selected type
              onPressed: (!valid || isSaving) ? null : () async {
                final navigator = Navigator.of(context);
                setState(() { isSaving = true; error = ''; });
                try {
                  await ColdmountService().postAnnouncement(
                    title: titleCtrl.text.trim(),
                    body: bodyCtrl.text.trim(), type: type);
                  navigator.pop();
                } catch (e) {
                  if (!mounted) return;
                  setState(() { isSaving = false; error = 'Post failed: $e'; });
                }
              },
              child: Text(isSaving ? 'Posting…' : 'Post'))),
        ])),
    );
  }
}
