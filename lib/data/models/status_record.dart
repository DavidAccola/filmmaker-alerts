import 'package:hive/hive.dart';

part 'status_record.g.dart';

@HiveType(typeId: 44)
enum WatchStatus {
  @HiveField(0)
  wantToWatch,

  @HiveField(1)
  inProgress,

  @HiveField(2)
  watched,

  @HiveField(3)
  dnf,
}

@HiveType(typeId: 43)
class StatusRecord {
  @HiveField(0)
  final WatchStatus status;

  @HiveField(1)
  final DateTime setAt;

  @HiveField(2)
  final List<DateTime>? watchDates;

  StatusRecord({
    required this.status,
    required this.setAt,
    this.watchDates,
  });

  DateTime? get lastWatchDate =>
      watchDates?.isNotEmpty == true ? watchDates!.last : null;

  int get watchCount => watchDates?.length ?? 0;

  StatusRecord copyWith({
    WatchStatus? status,
    DateTime? setAt,
    List<DateTime>? watchDates,
  }) {
    return StatusRecord(
      status: status ?? this.status,
      setAt: setAt ?? this.setAt,
      watchDates: watchDates ?? this.watchDates,
    );
  }
}
