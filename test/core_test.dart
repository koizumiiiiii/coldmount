import 'package:coldmount/core/theme.dart';
import 'package:coldmount/core/utils.dart';
import 'package:coldmount/screens/tenant/tenant_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('genTempPass (C-WB-04)', () {
    test('carries CM prefix + 6 characters', () {
      final p = genTempPass();
      expect(p.startsWith('CM'), isTrue);
      expect(p.length, 8);
    });

    test('uses unambiguous charset', () {
      for (var i = 0; i < 50; i++) {
        final p = genTempPass().substring(2);
        expect(RegExp(r'^[A-Z2-9]+$').hasMatch(p), isTrue);
        expect(p.contains('0'), isFalse);
        expect(p.contains('1'), isFalse);
      }
    });
  });

  group('genReceiptNo', () {
    test('zero-pads sequence', () {
      expect(genReceiptNo(1), 'CM-2509-001');
      expect(genReceiptNo(42), 'CM-2509-042');
    });
  });

  group('computeRefund (security − deductions, floor 0)', () {
    test('normal case', () {
      expect(computeRefund(5500, 800), 4700);
    });

    test('no deductions refunds full security', () {
      expect(computeRefund(5500, 0), 5500);
    });

    test('over-deduction floors at zero, never negative', () {
      expect(computeRefund(5500, 9000), 0);
    });
  });

  group('shortDate', () {
    test('formats like Sep 2, 2025', () {
      expect(shortDate(DateTime(2025, 9, 2)), 'Sep 2, 2025');
      expect(shortDate(DateTime(2026, 1, 15)), 'Jan 15, 2026');
    });
  });

  group('peso', () {
    test('formats whole amounts', () {
      expect(peso(5500), '₱5,500');
    });
  });

  group('leaseProgress (never hardcoded middle)', () {
    test('fresh 12-month lease starts near zero', () {
      final now = DateTime.now();
      final lease = {
        'startTs': now.millisecondsSinceEpoch,
        'endTs': DateTime(now.year + 1, now.month, now.day)
          .millisecondsSinceEpoch,
        'months': 12,
      };
      expect(leaseProgress(lease), lessThan(0.1));
    });

    test('finished lease reads 1.0', () {
      final lease = {
        'startTs': DateTime(2024, 1, 5).millisecondsSinceEpoch,
        'endTs': DateTime(2025, 1, 4).millisecondsSinceEpoch,
        'months': 12,
      };
      expect(leaseProgress(lease), 1.0);
    });

    test('unparseable dates safely read 0.0', () {
      expect(leaseProgress({'start': 'someday', 'end': ''}), 0.0);
    });

    test('label counts elapsed months', () {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 3, 1);
      final lease = {
        'startTs': start.millisecondsSinceEpoch,
        'endTs': DateTime(now.year + 1, now.month, 1)
          .millisecondsSinceEpoch,
        'months': 12,
      };
      expect(leaseProgressLabel(lease), contains('of 12 months'));
    });
  });

  group('parseShortDate', () {
    test('parses Sep 2, 2025', () {
      expect(parseShortDate('Sep 2, 2025'), DateTime(2025, 9, 2));
    });

    test('rejects garbage', () {
      expect(parseShortDate('someday'), isNull);
      expect(parseShortDate(''), isNull);
    });
  });

  group('billingMonth', () {
    test('current month label + indexes', () {
      final now = DateTime.now();
      final b = billingMonth();
      expect(b['year'], now.year);
      expect(b['monthIndex'], now.month);
    });

    test('monthsAgo walks back', () {
      final b = billingMonth(monthsAgo: 1);
      final now = DateTime.now();
      final d = DateTime(now.year, now.month - 1, 1);
      expect(b['year'], d.year);
      expect(b['monthIndex'], d.month);
    });
  });

  group('paymentPeriod', () {
    test('prefers stored year/monthIndex', () {
      expect(paymentPeriod({'year': 2025, 'monthIndex': 9}),
        {'year': 2025, 'month': 9});
    });

    test('falls back to label parsing', () {
      expect(paymentPeriod({'month': 'September 2025'}),
        {'year': 2025, 'month': 9});
    });
  });

  group('summarizeRevenue', () {
    List<Map<String, dynamic>> docs() => [
      {'month': 'September 2026', 'year': 2026, 'monthIndex': 9,
        'amount': 5500, 'status': 'verified', 'unit': '201'},
      {'month': 'October 2026', 'year': 2026, 'monthIndex': 10,
        'amount': 5500, 'status': 'verified', 'unit': '201'},
      {'month': 'October 2026', 'year': 2026, 'monthIndex': 10,
        'amount': 5200, 'status': 'verified', 'unit': '101'},
      {'month': 'November 2026', 'year': 2026, 'monthIndex': 11,
        'amount': 5500, 'status': 'pending', 'unit': '201'},
      {'month': 'September 2025', 'amount': 5500,
        'status': 'verified', 'unit': '201'},
    ];

    test('year totals, monthly buckets, per-unit split', () {
      final s = summarizeRevenue(docs(), 2026);
      expect(s['collected'], 5500 + 5500 + 5200);
      expect(s['collectedCount'], 3);
      expect(s['outstanding'], 5500);
      expect(s['pendingCount'], 1);
      expect((s['monthly'] as List<double>)[8], 5500);
      expect((s['monthly'] as List<double>)[9], 5500 + 5200);
      expect((s['perUnit'] as Map<String, double>)['201'], 5500 + 5500);
      expect((s['perUnit'] as Map<String, double>)['101'], 5200);
    });

    test('other years excluded (legacy label fallback works)', () {
      final s = summarizeRevenue(docs(), 2025);
      expect(s['collected'], 5500);
      expect((s['monthly'] as List<double>)[8], 5500);
    });

    test('empty list zeroes everything', () {
      final s = summarizeRevenue([], 2026);
      expect(s['collected'], 0);
      expect(s['outstanding'], 0);
      expect((s['monthly'] as List<double>).every((v) => v == 0), isTrue);
      expect((s['perUnit'] as Map<String, double>).isEmpty, isTrue);
    });
  });
}
