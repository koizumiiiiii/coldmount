// demo utilities and lease text for offline testing and previews
import '../models/models.dart';

// sample utility bills used for previews and offline demos
final utilitiesData = [
  const UtilityBill(id: 1, type: 'Electricity', amount: 1284, due: 'Sep 10, 2025', status: 'unpaid', period: 'August 2025', detail: '142 kWh @ ₱9.04/kWh'),
  const UtilityBill(id: 2, type: 'Water', amount: 350, due: 'Sep 10, 2025', status: 'unpaid', period: 'August 2025', detail: 'Flat rate'),
  const UtilityBill(id: 3, type: 'Internet', amount: 999, due: 'Sep 1, 2025', status: 'paid', period: 'September 2025', detail: '50Mbps fiber (shared)'),
  const UtilityBill(id: 4, type: 'Cable', amount: 499, due: 'Sep 1, 2025', status: 'paid', period: 'September 2025', detail: 'Basic cable'),
];

// standard lease terms text shown during tenant onboarding flow
const leaseTerms = '''LEASE AGREEMENT — COLDMOUNT BOARDING HOUSE

1. TERM: Twelve (12) months from the start date shown on your lease.
2. RENT: Monthly rent due on/before the 5th. ₱300 late fee after the 5th.
3. DEPOSITS: 2 months advance + 1 month security, paid before move-in.
4. UTILITIES: Water, electricity, internet, cable billed separately.
5. HOUSE RULES: No overnight guests without notice. Quiet hours 10PM–6AM. No pets without permission.
6. MAINTENANCE: Report via app. Negligence deducted from deposit.
7. TERMINATION: 30 days notice. Early termination forfeits advance.
8. CONFORME: Tenant acknowledges and agrees to house rules.''';
