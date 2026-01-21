// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'season_status_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SeasonStatusEntryAdapter extends TypeAdapter<SeasonStatusEntry> {
  @override
  final int typeId = 46;

  @override
  SeasonStatusEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SeasonStatusEntry(
      showId: fields[0] as int,
      seasonNumber: fields[1] as int,
      airDate: fields[2] as DateTime?,
      statusRecords: (fields[3] as List?)?.cast<StatusRecord>(),
    );
  }

  @override
  void write(BinaryWriter writer, SeasonStatusEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.showId)
      ..writeByte(1)
      ..write(obj.seasonNumber)
      ..writeByte(2)
      ..write(obj.airDate)
      ..writeByte(3)
      ..write(obj.statusRecords);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeasonStatusEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
