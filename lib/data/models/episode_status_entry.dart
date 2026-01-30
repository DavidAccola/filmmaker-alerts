import 'package:hive/hive.dart';
import 'status_record.dart'; // For StatusRecord

part 'episode_status_entry.g.dart';

@HiveType(typeId: 45)
class EpisodeStatusEntry extends HiveObject {
  @HiveField(0)
  late int showId;

  @HiveField(1)
  late int seasonNumber;

  @HiveField(2)
  late int episodeNumber;

  @HiveField(3)
  late String episodeTitle;

  @HiveField(4)
  late DateTime? airDate;

  @HiveField(5)
  late List<StatusRecord> statusRecords;

  EpisodeStatusEntry({
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    this.airDate,
    List<StatusRecord>? statusRecords,
  }) : statusRecords = statusRecords ?? [];

  String get uniqueKey => '${showId}_${seasonNumber}_$episodeNumber';

  bool get isReleased {
    if (airDate == null) return true;
    return airDate!.isBefore(DateTime.now());
  }
}
