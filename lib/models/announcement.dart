// announcement model used for community news and updates feed
// community announcement with title body date and type
class Announcement {
// announcement identity plus display title date body and type
  final int id; final String title, date, body, type;
  const Announcement({required this.id, required this.title, required this.date,
    required this.body, required this.type});
}
