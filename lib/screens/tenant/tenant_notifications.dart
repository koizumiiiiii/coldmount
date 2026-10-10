import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// notifications sheet that combines violations refunds and announcements
class NotificationsPanel extends StatelessWidget {
  final String uid;
  const NotificationsPanel({super.key, required this.uid});

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.month}/${d.day}/${d.year}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final svc = ColdmountService();
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.8,
      builder: (_, c) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Notifications',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // shows violations that the admin assigned to this tenant
        StreamBuilder<QuerySnapshot>(
          stream: svc.getTenantViolations(uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return CmErrorCard(
                title: 'could not load violations', error: snap.error);
            }
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionLabel(label: 'violations'),
              for (final d in ColdmountService.sortByCreatedDesc(docs))
                Builder(builder: (_) {
                  final v = d.data() as Map<String, dynamic>;
                  return CmCard(child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: Text('${v['title'] ?? 'violation'}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${v['notes'] ?? ''}\n${_fmtDate(v['date'])}'),
                    trailing: CmBadge(
                      label: '${v['severity'] ?? 'minor'}',
                      kind: '${v['severity'] ?? 'minor'}'),
                    dense: true));
                }),
            ]);
          }),
        // shows move out refunds recorded for this tenant
        StreamBuilder<QuerySnapshot>(
          stream: svc.getTenantRefunds(uid),
          builder: (context, snap) {
            if (snap.hasError) return const SizedBox.shrink();
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionLabel(label: 'refunds'),
              for (final d in ColdmountService.sortByCreatedDesc(docs))
                Builder(builder: (_) {
                  final r = d.data() as Map<String, dynamic>;
                  return CmCard(child: ListTile(
                    leading: const Icon(Icons.payments, color: Colors.green),
                    title: Text(
                      'refund ${peso((r['refund'] as num?)?.toDouble() ?? 0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'security ${peso((r['security'] as num?)?.toDouble() ?? 0)} − deductions ${peso((r['deductionsTotal'] as num?)?.toDouble() ?? 0)}'),
                    dense: true));
                }),
            ]);
          }),
        // shows latest announcements published by the property admin
        StreamBuilder<QuerySnapshot>(
          stream: svc.getAnnouncements(limit: 5),
          builder: (context, snap) {
            if (snap.hasError) return const SizedBox.shrink();
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionLabel(label: 'announcements'),
              for (final d in docs)
                Builder(builder: (_) {
                  final a = d.data() as Map<String, dynamic>;
                  final warning = (a['type'] as String?) == 'warning';
                  return CmCard(child: ListTile(
                    leading: Icon(warning ? Icons.warning : Icons.campaign,
                      color: warning ? Colors.orange : CmColors.primary),
                    title: Text('${a['title'] ?? ''}'),
                    subtitle: Text('${a['body'] ?? ''}'),
                    dense: true));
                }),
            ]);
          }),
      ]));
  }
}
