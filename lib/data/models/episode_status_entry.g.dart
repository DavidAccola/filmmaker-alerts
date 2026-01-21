// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode_status_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EpisodeStatusEntryAdapter extends TypeAdapter<EpisodeStatusEntry> {
  @override
  final int typeId = 45;

  @override
  EpisodeStatusEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EpisodeStatusEntry(
      showId: fields[0] as int,
      seasonNumber: fields[1] as int,
      episodeNumber: fields[2] as int,
      episodeTitle: fields[3] as String,
      airDate: fields[4] as DateTime?,
      statusRecords: (fields[5] as List?)?.cast<StatusRecord>(),
    );
  }

  @override
  void write(BinaryWriter writer, EpisodeStatusEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.showId)
      ..writeByte(1)
      ..write(obj.seasonNumber)
      ..writeByte(2)
      ..write(obj.episodeNumber)
      ..writeByte(3)
      ..write(obj.episodeTitle)
      ..writeByte(4)
      ..write(obj.airDate)
      ..writeByte(5)
      ..write(obj.statusRecords);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodeStatusEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
