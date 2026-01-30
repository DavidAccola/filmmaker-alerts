import 'package:hive/hive.dart';
import 'status_record.dart';

part 'movie_status_entry.g.dart';

/// Represents the status of an individual movie within a collection
@HiveType(typeId: 47)
class MovieStatusEntry extends HiveObject {
  @HiveField(0)
  late int collectionId;
  
  @HiveField(1)
  late int movieId;
  
  @HiveField(2)
  late String movieTitle;
  
  @HiveField(3)
  late DateTime? releaseDate;
  
  @HiveField(4)
  late List<StatusRecord> statusRecords;
  
  MovieStatusEntry({
    required this.collectionId,
    required this.movieId,
    required this.movieTitle,
    this.releaseDate,
    List<StatusRecord>? statusRecords,
  }) : statusRecords = statusRecords ?? [];
  
  String get uniqueKey => '${collectionId}_$movieId';
  
  bool get isReleased {
    if (releaseDate == null) return true;
    return releaseDate!.isBefore(DateTime.now());
  }
  
  /// Gets the most recent status record for a specific status type
  StatusRecord? getStatusRecord(WatchStatus status) {
    final records = statusRecords.where((r) => r.status == status).toList();
    if (records.isEmpty) return null;
    records.sort((a, b) => b.setAt.compareTo(a.setAt));
    return records.first;
  }
  
  /// Checks if the movie has a specific status
  bool hasStatus(WatchStatus status) {
    return statusRecords.any((r) => r.status == status);
  }
  
  /// Gets all current statuses (latest record for each status type)
  List<WatchStatus> get currentStatuses {
    final statusMap = <WatchStatus, DateTime>{};
    for (final record in statusRecords) {
      final existing = statusMap[record.status];
      if (existing == null || record.setAt.isAfter(existing)) {
        statusMap[record.status] = record.setAt;
      }
    }
    return statusMap.keys.toList();
  }
}