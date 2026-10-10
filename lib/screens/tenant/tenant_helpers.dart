import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';

// formats date as full month name plus year label
String monthLabel(DateTime d) {
  const months = ['January','February','March','April','May','June','July',
    'August','September','October','November','December'];
  return '${months[d.month - 1]} ${d.year}';
}

// returns true when month is already pending or verified
bool monthLocked(List<QueryDocumentSnapshot> docs, String month) {
  return docs.any((d) {
    final m = d.data() as Map<String, dynamic>;
    final s = (m['status'] as String?) ?? '';
    return (m['month'] as String?) == month &&
      (s == 'pending' || s == 'verified');
  });
}

// builds small deposit box showing label amount and note
Widget depBox(String l, double v, String s) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: Colors.grey.shade100,
    borderRadius: BorderRadius.circular(12)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 12)),
    Text(peso(v), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
    Text(s, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]));

const _shortMonths = ['Jan','Feb','Mar','Apr','May','Jun','Jul',
  'Aug','Sep','Oct','Nov','Dec'];

// parses short date text into a datetime object safely
DateTime? parseShortDate(String s) {
  final m = RegExp(r'^([A-Za-z]{3})\s+(\d{1,2}),\s*(\d{4})$')
    .firstMatch(s.trim());
  if (m == null) return null;
  final mi = _shortMonths.indexWhere(
    (mo) => mo.toLowerCase() == m.group(1)!.toLowerCase());
  if (mi < 0) return null;
  return DateTime(int.parse(m.group(3)!), mi + 1, int.parse(m.group(2)!));
}

// calculates lease progress as value between zero and one
double leaseProgress(Map<String, dynamic> lease) {
  DateTime? start, end;
  final startTs = lease['startTs'];
  final endTs = lease['endTs'];
  if (startTs is int && endTs is int) {
    start = DateTime.fromMillisecondsSinceEpoch(startTs);
    end = DateTime.fromMillisecondsSinceEpoch(endTs);
  } else {
    start = parseShortDate('${lease['start'] ?? ''}');
    end = parseShortDate('${lease['end'] ?? ''}');
  }
  if (start == null || end == null || !end.isAfter(start)) return 0.0;
  final now = DateTime.now();
  if (now.isBefore(start)) return 0.0;
  if (!now.isBefore(end)) return 1.0;
  return now.difference(start).inMilliseconds /
    end.difference(start).inMilliseconds;
}

// builds elapsed of total months label for lease
String leaseProgressLabel(Map<String, dynamic> lease) {
  DateTime? start, end;
  final startTs = lease['startTs'];
  final endTs = lease['endTs'];
  if (startTs is int && endTs is int) {
    start = DateTime.fromMillisecondsSinceEpoch(startTs);
    end = DateTime.fromMillisecondsSinceEpoch(endTs);
  } else {
    start = parseShortDate('${lease['start'] ?? ''}');
    end = parseShortDate('${lease['end'] ?? ''}');
  }
  final total = (lease['months'] as num?)?.toInt() ?? 12;
  if (start == null || end == null || !end.isAfter(start)) {
    return '$total months term';
  }
  final now = DateTime.now();
  var elapsed = (now.year - start.year) * 12 + now.month - start.month;
  if (now.day < start.day) elapsed -= 1;
  elapsed = elapsed.clamp(0, total);
  return '$elapsed of $total months';
}
