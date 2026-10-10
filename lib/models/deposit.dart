// deposit model tracking advance and security payment totals
// move in deposit showing advance security and total amounts
class Deposit {
// deposit identity plus tenant name and unit number
  final int id; final String tenant, unit;
// advance security and computed total amounts for move in
  final double advance, security, total;
  const Deposit({required this.id, required this.tenant, required this.unit,
    required this.advance, required this.security, required this.total});
}
