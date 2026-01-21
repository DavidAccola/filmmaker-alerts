// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_status_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MovieStatusEntryAdapter extends TypeAdapter<MovieStatusEntry> {
  @override
  final int typeId = 47;

  @override
  MovieStatusEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MovieStatusEntry(
      collectionId: fields[0] as int,
      movieId: fields[1] as int,
      movieTitle: fields[2] as String,
      releaseDate: fields[3] as DateTime?,
      statusRecords: (fields[4] as List?)?.cast<StatusRecord>(),
    );
  }

  @override
  void write(BinaryWriter writer, MovieStatusEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.collectionId)
      ..writeByte(1)
      ..write(obj.movieId)
      ..writeByte(2)
      ..write(obj.movieTitle)
      ..writeByte(3)
      ..write(obj.releaseDate)
      ..writeByte(4)
      ..write(obj.statusRecords);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieStatusEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
