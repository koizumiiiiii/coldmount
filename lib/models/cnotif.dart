// notification model for inbox alerts and tenant reminders
// inbox notification with title body time and read flag
class CNotif {
// notification identity plus type title body time and flag
  final int id; final String type, title, body, time; final bool read;
  const CNotif({required this.id, required this.type, required this.title,
    required this.body, required this.time, required this.read});
}
