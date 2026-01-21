// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'watchlist_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContributorSnapshotAdapter extends TypeAdapter<ContributorSnapshot> {
  @override
  final int typeId = 42;

  @override
  ContributorSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContributorSnapshot(
      contributorId: fields[0] as int,
      name: fields[1] as String,
      role: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ContributorSnapshot obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.contributorId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.role);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributorSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WatchlistEntryAdapter extends TypeAdapter<WatchlistEntry> {
  @override
  final int typeId = 41;

  @override
  WatchlistEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WatchlistEntry(
      tmdbId: fields[0] as int,
      type: fields[1] as WorkType,
      title: fields[2] as String,
      posterPath: fields[3] as String?,
      releaseDate: fields[4] as DateTime?,
      releaseType: fields[5] as ReleaseType?,
      addedAt: fields[6] as DateTime,
      addRank: fields[7] as int,
      userRank: fields[8] as int?,
      isSnoozed: fields[9] as bool,
      notificationsSnoozed: fields[10] as bool,
      overriddenGenre: fields[11] as String?,
      genreListId: fields[12] as String?,
      followedContributors: (fields[13] as List?)?.cast<ContributorSnapshot>(),
      statusRecords: (fields[14] as List?)?.cast<StatusRecord>(),
    );
  }

  @override
  void write(BinaryWriter writer, WatchlistEntry obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.posterPath)
      ..writeByte(4)
      ..write(obj.releaseDate)
      ..writeByte(5)
      ..write(obj.releaseType)
      ..writeByte(6)
      ..write(obj.addedAt)
      ..writeByte(7)
      ..write(obj.addRank)
      ..writeByte(8)
      ..write(obj.userRank)
      ..writeByte(9)
      ..write(obj.isSnoozed)
      ..writeByte(10)
      ..write(obj.notificationsSnoozed)
      ..writeByte(11)
      ..write(obj.overriddenGenre)
      ..writeByte(12)
      ..write(obj.genreListId)
      ..writeByte(13)
      ..write(obj.followedContributors)
      ..writeByte(14)
      ..write(obj.statusRecords);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
