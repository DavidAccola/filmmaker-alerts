// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TvShowCacheEntryAdapter extends TypeAdapter<TvShowCacheEntry> {
  @override
  final int typeId = 9;

  @override
  TvShowCacheEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TvShowCacheEntry(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      posterPath: fields[2] as String?,
      firstAirDate: fields[3] as String?,
      status: fields[4] as String?,
      creators: (fields[5] as List).cast<String>(),
      numberOfSeasons: fields[6] as int?,
      imdbId: fields[7] as String?,
      lastAirDate: fields[8] as String?,
      nextEpisodeToAir: (fields[9] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, TvShowCacheEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.posterPath)
      ..writeByte(3)
      ..write(obj.firstAirDate)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.creators)
      ..writeByte(6)
      ..write(obj.numberOfSeasons)
      ..writeByte(7)
      ..write(obj.imdbId)
      ..writeByte(8)
      ..write(obj.lastAirDate)
      ..writeByte(9)
      ..write(obj.nextEpisodeToAir);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvShowCacheEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TvEpisodeCacheEntryAdapter extends TypeAdapter<TvEpisodeCacheEntry> {
  @override
  final int typeId = 10;

  @override
  TvEpisodeCacheEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TvEpisodeCacheEntry(
      tmdbId: fields[0] as int,
      showId: fields[1] as int,
      seasonNumber: fields[2] as int,
      episodeNumber: fields[3] as int,
      name: fields[4] as String,
      airDate: fields[5] as String?,
      stillPath: fields[6] as String?,
      directors: (fields[7] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, TvEpisodeCacheEntry obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.showId)
      ..writeByte(2)
      ..write(obj.seasonNumber)
      ..writeByte(3)
      ..write(obj.episodeNumber)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.airDate)
      ..writeByte(6)
      ..write(obj.stillPath)
      ..writeByte(7)
      ..write(obj.directors);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvEpisodeCacheEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
