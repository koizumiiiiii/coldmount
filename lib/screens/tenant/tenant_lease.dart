import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/mock_data.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/common.dart';
import 'tenant_helpers.dart';

// lease tab that shows details deposits and conforme signing
class TenantLease extends StatefulWidget {
  final String uid;
  final String? leaseId;
  final Map<String, dynamic>? lease;
  final bool leaseError;
  final String tenantName;
  final String tenantUnit;
  const TenantLease({super.key, required this.uid, this.leaseId,
    required this.lease, this.leaseError = false,
    required this.tenantName, required this.tenantUnit});
  @override
  State<TenantLease> createState() => _TenantLeaseState();
}

class _TenantLeaseState extends State<TenantLease> {
  bool conformeSigned = false, hasRead = false, agreed = false;
  bool signing = false;
  String signError = '';

  @override
  void initState() {
    super.initState();
    conformeSigned = widget.lease?['conformeSigned'] == true;
  }

  @override
  void didUpdateWidget(TenantLease old) {
    super.didUpdateWidget(old);
    if (widget.lease?['conformeSigned'] == true && !conformeSigned) {
      conformeSigned = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lease = widget.lease;
    if (lease == null) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.leaseError)
          const CmCard(child: ListTile(
            leading: Icon(Icons.error, color: Colors.red),
            title: Text('Could not load lease'),
            subtitle: Text('Check your connection and reopen this tab.'))),
        if (!widget.leaseError)
          const CmCard(child: ListTile(
            leading: Icon(Icons.description),
            title: Text('No active lease'),
            subtitle: Text('Ask your admin to create your lease agreement.'))),
      ]);
    }
    final rent = (lease['rent'] as num).toDouble();
    return ListView(padding: const EdgeInsets.all(16), children: [
      CmCard(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('LEASE DETAILS'), CmBadge(label: 'Active', kind: 'active')]),
        ListTile(leading: const Icon(Icons.calendar_month),
          title: Text('${lease['start']}'), subtitle: const Text('Start Date'), dense: true),
        ListTile(leading: const Icon(Icons.calendar_month),
          title: Text('${lease['end']}'), subtitle: const Text('End Date'), dense: true),
        ListTile(leading: const Icon(Icons.payments),
          title: Text(peso(rent)), subtitle: const Text('Monthly Rent'), dense: true),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('PROGRESS',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(leaseProgressLabel(lease),
                style: const TextStyle(fontSize: 11)),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: leaseProgress(lease), minHeight: 8),
          ])),
      ])),
      CmCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Conforme Acknowledgment',
          style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (!conformeSigned) ...[
          Container(height: 140,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12)),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 12) {
                  if (!hasRead) setState(() => hasRead = true);
                }
                return false;
              },
              child: SingleChildScrollView(child: Text(leaseTerms,
                style: const TextStyle(fontSize: 12))))),
          if (!hasRead)
            const Text('Scroll to the bottom to unlock signing',
              style: TextStyle(color: Colors.amber, fontSize: 12)),
          CheckboxListTile(value: agreed,
            onChanged: hasRead ? (v) => setState(() => agreed = v ?? false) : null,
            title: const Text('I have read and fully understood all terms.',
              style: TextStyle(fontSize: 12))),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              // signs conforme digitally after reading and agreeing to terms
              onPressed: (hasRead && agreed && !signing)
                ? () async {
                    if (widget.leaseId == null) return;
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() { signing = true; signError = ''; });
                    try {
                      await ColdmountService().signConforme(
                        leaseId: widget.leaseId!,
                        tenantName: widget.tenantName);
                      if (!mounted) return;
                      setState(() {
                        signing = false;
                        conformeSigned = true;
                      });
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        signing = false;
                        signError = 'Signing failed: $e';
                      });
                      messenger.showSnackBar(SnackBar(
                        content: Text('Signing failed: $e')));
                    }
                  }
                : null,
              child: Text(signing ? 'Signing…' : 'Sign Digitally'))),
          if (signError.isNotEmpty)
            Text(signError,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ] else
          Builder(builder: (_) {
            final by = (lease['conformeBy'] as String?) ?? widget.tenantName;
            final at = lease['conformeAt'];
            var when = '';
            if (at is Timestamp) {
              final d = at.toDate();
              when = ' · ${d.month}/${d.day}/${d.year}';
            }
            return ListTile(
              leading: const Icon(Icons.verified, color: Colors.green),
              title: const Text('Lease Terms Acknowledged'),
              subtitle: Text(
                'Digitally confirmed$when · $by · Unit ${widget.tenantUnit}'));
          }),
      ])),
      CmCard(child: Column(children: [
        const SectionLabel(label: 'Deposit Tracker'),
        Row(children: [
          Expanded(child: depBox('Advance',
            ((lease['advance'] as num?)?.toDouble() ?? rent * 2), '2 months rent')),
          const SizedBox(width: 8),
          Expanded(child: depBox('Security',
            ((lease['security'] as num?)?.toDouble() ?? rent), '1 month rent')),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Total on Hold'),
            Text(peso(((lease['advance'] as num?)?.toDouble() ?? rent * 2) +
              ((lease['security'] as num?)?.toDouble() ?? rent)),
              style: const TextStyle(fontWeight: FontWeight.w900))]),
        const Text('Refundable within 30 days of move-out, less deductions.',
          style: TextStyle(fontSize: 12, color: Colors.blue)),
      ])),
      // shows recorded move out refund with deductions breakdown
      StreamBuilder<QuerySnapshot>(
        stream: ColdmountService().getTenantRefunds(widget.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const CmCard(child: ListTile(
              leading: Icon(Icons.error, color: Colors.red),
              title: Text('Could not load refund record',
                style: TextStyle(fontSize: 12)),
              dense: true));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }
          final docs = ColdmountService.sortByCreatedDesc(snap.data!.docs);
          final r = docs.first.data() as Map<String, dynamic>;
          final items = (r['deductions'] as List?) ?? [];
          return CmCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel(label: 'Move-out refund — recorded'),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Refundable'),
              Text(peso((r['refund'] as num?)?.toDouble() ?? 0),
                style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w900, color: Colors.green)),
            ]),
            Text('Security ${peso((r['security'] as num?)?.toDouble() ?? 0)}'
              ' − deductions ${peso((r['deductionsTotal'] as num?)?.toDouble() ?? 0)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
            for (final it in items)
              Text('• ${it['desc']} — ${peso((it['amount'] as num?)?.toDouble() ?? 0)}',
                style: const TextStyle(fontSize: 12)),
          ]));
        }),
      // shows tenant violations issued by the property admin
      StreamBuilder<QuerySnapshot>(
        stream: ColdmountService().getTenantViolations(widget.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return const CmCard(child: ListTile(
              leading: Icon(Icons.error, color: Colors.red),
              title: Text('Could not load violations',
                style: TextStyle(fontSize: 12)),
              dense: true));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }
          final docs = ColdmountService.sortByCreatedDesc(snap.data!.docs);
          String fmtDate(Timestamp? ts) => ts == null ? '' :
            '${ts.toDate().month}/${ts.toDate().day}/${ts.toDate().year}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel(label: 'My violations'),
            for (final d in docs)
              Builder(builder: (_) {
                final v = d.data() as Map<String, dynamic>;
                final severity = (v['severity'] as String?) ?? 'minor';
                return CmCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text('${v['title'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
                    CmBadge(label: severity, kind: severity)]),
                  Text(fmtDate(v['date'] as Timestamp?),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('${v['notes'] ?? ''}',
                    style: const TextStyle(fontSize: 12)),
                ]));
              }),
          ]);
        }),
    ]);
  }
}
