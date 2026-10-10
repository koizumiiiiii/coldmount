import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/coldmount_service.dart';
import '../../widgets/async_views.dart';
import '../../widgets/common.dart';

// admin dashboard that summarizes occupancy pending payments and revenue
class AdminDashboard extends StatefulWidget {
  final void Function(int tab) onNavigateTab;
  final void Function(String screen) onOpenMore;
  const AdminDashboard({super.key, required this.onNavigateTab,
    required this.onOpenMore});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

// dashboard state that tracks selected revenue year filter
class _AdminDashboardState extends State<AdminDashboard> {
  late int year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final svc = ColdmountService();
    return StreamBuilder<QuerySnapshot>(
      stream: svc.getUnits(),
      builder: (context, unitSnap) => StreamBuilder<QuerySnapshot>(
        stream: svc.getPendingPayments(),
        builder: (context, pendSnap) {
          final unitDocs = unitSnap.data?.docs ?? [];
          final occupied = unitDocs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            return (m['status'] as String?) == 'occupied';
          }).length;
          final pending = pendSnap.data?.docs.length ?? 0;
          return ListView(padding: const EdgeInsets.all(16), children: [
            // occupancy and pending cards that show live unit counts
            GridView.count(crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
              children: [
                CmCard(child: Column(children: [
                  const Icon(Icons.apartment),
                  Text('$occupied/${unitDocs.length}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Text('Occupancy', style: TextStyle(fontSize: 11))])),
                CmCard(child: Column(children: [
                  const Icon(Icons.pending),
                  Text('$pending',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const Text('Pending Verify', style: TextStyle(fontSize: 11))])),
              ]),
            if (pending > 0)
              // pending verification banner that jumps to payments tab for review
              CmCard(child: ListTile(
                leading: const Icon(Icons.receipt, color: Colors.amber),
                title: Text('$pending payment${pending == 1 ? '' : 's'} need${pending == 1 ? 's' : ''} verification'),
                trailing: TextButton(onPressed: () => widget.onNavigateTab(4),
                  child: const Text('Review')))),
            // revenue year view that aggregates verified payments by month
            StreamBuilder<QuerySnapshot>(
              stream: svc.getAllPayments(),
              builder: (context, paySnap) {
                if (paySnap.connectionState == ConnectionState.waiting) {
                  return const CmLoading();
                }
                if (paySnap.hasError) {
                  return CmErrorCard(
                    title: 'Could not load revenue', error: paySnap.error);
                }
                final docs = (paySnap.data?.docs ?? [])
                  .map((d) => d.data() as Map<String, dynamic>)
                  .toList();
                final years = docs
                  .map((p) => paymentPeriod(p)['year'] ?? 0)
                  .where((y) => y > 2000)
                  .toSet()
                  .toList()..sort();
                if (!years.contains(DateTime.now().year)) {
                  years.add(DateTime.now().year);
                  years.sort();
                }
                if (!years.contains(year)) year = years.last;
                final s = summarizeRevenue(docs, year);
                final monthly = s['monthly'] as List<double>;
                final perUnit = s['perUnit'] as Map<String, double>;
                final maxBar = monthly.fold<double>(
                  1, (m, v) => v > m ? v : m);
                return CmCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('REVENUE',
                        style: TextStyle(
                          fontSize: 11, color: Colors.grey,
                          fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: year,
                        items: [
                          for (final y in years)
                            DropdownMenuItem(value: y, child: Text('$y')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => year = v);
                        }),
                    ]),
                  const SizedBox(height: 4),
                  Text(peso((s['collected'] as double)),
                    style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w900)),
                  Text(
                    'collected in $year · ${s['collectedCount']} verified payment${(s['collectedCount'] as int) == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    'Outstanding: ${peso((s['outstanding'] as double))} '
                    '(${s['pendingCount']} pending)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // monthly bars that visualize collected revenue across twelve months
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 12; i++)
                          Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  monthly[i] > 0
                                    ? '${(monthly[i] / 1000).toStringAsFixed(monthly[i] >= 10000 ? 0 : 1)}k'
                                    : '',
                                  style: const TextStyle(fontSize: 8)),
                                Container(
                                  height: 70 * (monthly[i] / maxBar),
                                  decoration: BoxDecoration(
                                    color: monthly[i] > 0
                                      ? CmColors.primary
                                      : Colors.grey.shade200,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4))),
                                ),
                                Text(
                                  ['J','F','M','A','M','J','J','A','S','O','N','D'][i],
                                  style: const TextStyle(fontSize: 9)),
                              ],
                            ),
                          )),
                      ],
                    ),
                  ),
                  if (perUnit.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('BY UNIT',
                      style: TextStyle(
                        fontSize: 11, color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                    for (final e in perUnit.entries)
                      Padding(padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Unit ${e.key}',
                              style: const TextStyle(fontSize: 12)),
                            Text(peso(e.value),
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                          ])),
                  ],
                  if ((s['collected'] as double) == 0)
                    const Padding(padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No verified payments this year yet. Record past '
                        'payments from the Payments tab to build history.',
                        style: TextStyle(fontSize: 11, color: Colors.grey))),
                ]));
              }),
            // maintenance tickets card that opens maintenance queue when tapped
            StreamBuilder<QuerySnapshot>(
              stream: svc.getAllTickets(),
              builder: (context, tSnap) {
                final open = (tSnap.data?.docs ?? []).where((d) {
                  final s = ((d.data() as Map<String, dynamic>)['status'] as String?);
                  return s == 'submitted' || s == 'in-progress';
                }).length;
                return CmCard(child: ListTile(
                  leading: const Icon(Icons.build, color: Colors.blue),
                  title: Text('$open open maintenance ticket${open == 1 ? '' : 's'}'),
                  trailing: TextButton(
                    onPressed: () => widget.onOpenMore('maintenance'),
                    child: const Text('Open'))));
              }),
            // accounts hint card that guides admin to create users tab
            CmCard(child: ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Accounts are created by you'),
              subtitle: const Text('Use the Users tab → Add'),
              trailing: TextButton(onPressed: () => widget.onNavigateTab(2),
                child: const Text('Open')))),
          ]);
        }));
  }
}
