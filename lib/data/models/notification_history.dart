import 'package:hive/hive.dart';

part 'notification_history.g.dart';

@HiveType(typeId: 4)
class NotificationReason {
  @HiveField(0)
  final int contributorId;

  @HiveField(1)
  final String contributorName;

  @HiveField(2)
  final String department;

  @HiveField(3)
  final String? job;

  NotificationReason({
    required this.contributorId,
    required this.contributorName,
    required this.department,
    this.job,
  });
}

@HiveType(typeId: 5)
class NotificationEvent {
  @HiveField(0)
  final String releaseType;

  @HiveField(1)
  final String releaseDate;

  @HiveField(2)
  final String notifiedAt;

  NotificationEvent({
    required this.releaseType,
    required this.releaseDate,
    required this.notifiedAt,
  });
}

@HiveType(typeId: 3)
class NotificationHistoryEntry extends HiveObject {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  List<NotificationReason> reasons;

  @HiveField(2)
  List<NotificationEvent> notificationEvents;

  NotificationHistoryEntry({
    required this.tmdbId,
    required this.reasons,
    required this.notificationEvents,
  });
}