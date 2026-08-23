import 'package:hive/hive.dart';
import 'status_record.dart'; // For StatusRecord

part 'season_status_entry.g.dart';

@HiveType(typeId: 46)
class SeasonStatusEntry extends HiveObject {
  @HiveField(0)
  late int showId;

  @HiveField(1)
  late int seasonNumber;

  @HiveField(2)
  late DateTime? airDate;

  @HiveField(3)
  late List<StatusRecord> statusRecords;

  @HiveField(4)
  late int? userRating;

  SeasonStatusEntry({
    required this.showId,
    required this.seasonNumber,
    this.airDate,
    List<StatusRecord>? statusRecords,
    this.userRating,
  }) : statusRecords = statusRecords ?? [];

  String get uniqueKey => '${showId}_$seasonNumber';

  String get displayName =>
      seasonNumber == 0 ? 'Specials' : 'Season $seasonNumber';

  bool get isReleased {
    if (airDate == null) return true;
    return airDate!.isBefore(DateTime.now());
  }
}
