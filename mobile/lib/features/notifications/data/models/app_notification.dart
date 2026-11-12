class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
  });

  final String id;
  final String title;
  final String message;
  final bool isRead;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? 'Notifikasi',
    message: json['message']?.toString() ?? '',
    isRead: json['isRead'] == true,
  );
}
