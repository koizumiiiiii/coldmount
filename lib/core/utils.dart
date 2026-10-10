// helper utilities for passwords receipts dates and revenue summaries
import 'dart:math';

// gen temp password for new accounts
String genTempPass() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return 'CM${List.generate(6, (_) => chars[r.nextInt(chars.length)]).join()}';
}

// gen receipt no for verified payments
String genReceiptNo(int seq) =>
  'CM-2509-${seq.toString().padLeft(3, '0')}';

// short date label for lease display
String shortDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul',
    'Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

// computes refund as security minus total deductions never negative
double computeRefund(double security, double deductionsTotal) =>
  (security - deductionsTotal).clamp(0, double.infinity).toDouble();

// full month names used for revenue charts and billing labels
const revenueMonths = ['January','February','March','April','May','June','July',
  'August','September','October','November','December'];

const _revShort = ['Jan','Feb','Mar','Apr','May','Jun','Jul',
  'Aug','Sep','Oct','Nov','Dec'];

// billing month label for payment docs
Map<String, dynamic> billingMonth({int monthsAgo = 0}) {
  final now = DateTime.now();
  final d = DateTime(now.year, now.month - monthsAgo, 1);
  return {
    'label': '${revenueMonths[d.month - 1]} ${d.year}',
    'short': _revShort[d.month - 1],
    'year': d.year,
    'monthIndex': d.month,
  };
}

// get year + month index from payment doc
Map<String, int> paymentPeriod(Map<String, dynamic> p) {
  final y = p['year'];
  final m = p['monthIndex'];
  if (y is num && m is num) {
    return {'year': y.toInt(), 'month': m.toInt()};
  }
  final label = '${p['month'] ?? ''}';
  final parts = label.split(' ');
  final year = parts.length > 1 ? int.tryParse(parts.last) ?? 0 : 0;
  final mi = revenueMonths.indexWhere(
    (mo) => parts.isNotEmpty && mo.toLowerCase() == parts.first.toLowerCase());
  return {'year': year, 'month': mi >= 0 ? mi + 1 : 0};
}

// summarizes yearly revenue totals counts monthly and per unit
Map<String, dynamic> summarizeRevenue(
    List<Map<String, dynamic>> payments, int year) {
  final monthly = List<double>.filled(12, 0);
  final perUnit = <String, double>{};
  var collected = 0.0;
  var outstanding = 0.0;
  var collectedCount = 0;
  var pendingCount = 0;
  for (final p in payments) {
    final per = paymentPeriod(p);
    final amount = ((p['amount'] as num?)?.toDouble() ?? 0);
    final status = (p['status'] as String?) ?? '';
    if (status == 'pending') {
      outstanding += amount;
      pendingCount++;
    }
    if (per['year'] != year || status != 'verified') continue;
    collected += amount;
    collectedCount++;
    monthly[(per['month'] ?? 1) - 1] += amount;
    final unit = '${p['unit'] ?? '?'}';
    perUnit[unit] = (perUnit[unit] ?? 0) + amount;
  }
  return {
    'collected': collected,
    'outstanding': outstanding,
    'collectedCount': collectedCount,
    'pendingCount': pendingCount,
    'monthly': monthly,
    'perUnit': perUnit,
  };
}
