// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_cache_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MovieCacheEntryAdapter extends TypeAdapter<MovieCacheEntry> {
  @override
  final int typeId = 6;

  @override
  MovieCacheEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MovieCacheEntry(
      tmdbId: fields[0] as int,
      title: fields[1] as String,
      posterPath: fields[2] as String?,
      releaseDate: fields[3] as String?,
      popularity: fields[4] as double?,
      notified: fields[5] as bool? ?? false,
      imdbId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MovieCacheEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.posterPath)
      ..writeByte(3)
      ..write(obj.releaseDate)
      ..writeByte(4)
      ..write(obj.popularity)
      ..writeByte(5)
      ..write(obj.notified)
      ..writeByte(6)
      ..write(obj.imdbId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieCacheEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
