// violation model recording tenant offenses severity and resolution status
// house rule violation with severity notes and resolution status
class Violation {
// violation identity tenant unit title date severity and notes
  final int id; final String tenant, unit, title, date, severity, status, notes;
  const Violation({required this.id, required this.tenant, required this.unit,
    required this.title, required this.date, required this.severity,
    required this.status, required this.notes});
}
