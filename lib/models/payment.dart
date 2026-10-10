// payment model recording monthly rent transactions and verification status
// monthly rent payment with method receipt note and status
class Payment {
// payment identity month date method status receipt and note
  final int id; final String month, date, method, status, receipt, note;
// paid amount stored numerically for totals and peso display
  final double amount;
  const Payment({required this.id, required this.month, required this.amount,
    required this.date, required this.method, required this.status,
    required this.receipt, required this.note});
// returns copy with updated status receipt and note only
  Payment copyWith({String? status, String? receipt, String? note}) => Payment(
    id: id, month: month, amount: amount, date: date, method: method,
    status: status ?? this.status, receipt: receipt ?? this.receipt,
    note: note ?? this.note);
}
