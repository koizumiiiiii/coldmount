// maintenance ticket model for requests status and assignment tracking
// maintenance request with category assignee status and resolution date
class Ticket {
// ticket identity title category date status and assignment details
  final int id; final String title, category, date, status, desc, assignee, resolved;
  const Ticket({required this.id, required this.title, required this.category,
    required this.date, required this.status, required this.desc,
    required this.assignee, required this.resolved});
}
