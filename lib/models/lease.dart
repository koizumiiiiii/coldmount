// lease model linking tenants units rent and contract period
// rental contract linking tenant unit rent dates and status
class Lease {
// lease identity tenant unit dates and current contract status
  final int id; final String tenant, unit, start, end, status;
// monthly rent amount plus total duration in calendar months
  final double rent; final int months;
  const Lease({required this.id, required this.tenant, required this.unit,
    required this.start, required this.end, required this.rent,
    required this.status, required this.months});
}
