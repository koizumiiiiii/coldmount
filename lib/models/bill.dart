// utility bill model tracking charges due dates and status
// utility charge with amount due date period and status
class UtilityBill {
// bill identity plus type due status period and detail
  final int id; final String type, due, status, period, detail, method;
// billed amount preserved as numeric value for peso formatting
  final double amount;
  const UtilityBill({required this.id, required this.type, required this.amount,
    required this.due, required this.status, required this.period,
    required this.detail, this.method = ''});
// returns copy with updated status and payment method only
  UtilityBill copyWith({String? status, String? method}) => UtilityBill(
    id: id, type: type, amount: amount, due: due,
    status: status ?? this.status, period: period, detail: detail,
    method: method ?? this.method);
}
