// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tv_detail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TvShowDetailAdapter extends TypeAdapter<TvShowDetail> {
  @override
  final int typeId = 30;

  @override
  TvShowDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TvShowDetail(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      posterPath: fields[2] as String?,
      firstAirDate: fields[3] as DateTime?,
      lastAirDate: fields[4] as DateTime?,
      synopsis: fields[5] as String,
      tmdbRating: fields[6] as double?,
      voteCount: fields[7] as int?,
      status: fields[8] as String?,
      cast: (fields[9] as List).cast<CastMember>(),
      crew: (fields[10] as List).cast<CrewMember>(),
      seasons: (fields[11] as List).cast<TvSeason>(),
      streamingOptions: (fields[12] as List).cast<StreamingOption>(),
      imdbId: fields[13] as String?,
      numberOfEpisodes: fields[14] as int?,
      numberOfSeasons: fields[15] as int?,
      lastUpdated: fields[16] as DateTime?,
      popularity: fields[17] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, TvShowDetail obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.posterPath)
      ..writeByte(3)
      ..write(obj.firstAirDate)
      ..writeByte(4)
      ..write(obj.lastAirDate)
      ..writeByte(5)
      ..write(obj.synopsis)
      ..writeByte(6)
      ..write(obj.tmdbRating)
      ..writeByte(7)
      ..write(obj.voteCount)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.cast)
      ..writeByte(10)
      ..write(obj.crew)
      ..writeByte(11)
      ..write(obj.seasons)
      ..writeByte(12)
      ..write(obj.streamingOptions)
      ..writeByte(13)
      ..write(obj.imdbId)
      ..writeByte(14)
      ..write(obj.numberOfEpisodes)
      ..writeByte(15)
      ..write(obj.numberOfSeasons)
      ..writeByte(16)
      ..write(obj.lastUpdated)
      ..writeByte(17)
      ..write(obj.popularity)
      ..writeByte(18)
      ..write(obj._episodeRunTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvShowDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TvSeasonAdapter extends TypeAdapter<TvSeason> {
  @override
  final int typeId = 31;

  @override
  TvSeason read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TvSeason(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      seasonNumber: fields[2] as int,
      posterPath: fields[3] as String?,
      airDate: fields[4] as DateTime?,
      episodeCount: fields[5] as int,
      overview: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TvSeason obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.seasonNumber)
      ..writeByte(3)
      ..write(obj.posterPath)
      ..writeByte(4)
      ..write(obj.airDate)
      ..writeByte(5)
      ..write(obj.episodeCount)
      ..writeByte(6)
      ..write(obj.overview);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvSeasonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TvSeasonDetailAdapter extends TypeAdapter<TvSeasonDetail> {
  @override
  final int typeId = 33;

  @override
  TvSeasonDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TvSeasonDetail(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      seasonNumber: fields[2] as int,
      posterPath: fields[3] as String?,
      overview: fields[4] as String?,
      episodes: (fields[5] as List).cast<SeasonEpisode>(),
      airDate: fields[6] as DateTime?,
      lastUpdated: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TvSeasonDetail obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.seasonNumber)
      ..writeByte(3)
      ..write(obj.posterPath)
      ..writeByte(4)
      ..write(obj.overview)
      ..writeByte(5)
      ..write(obj.episodes)
      ..writeByte(6)
      ..write(obj.airDate)
      ..writeByte(7)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvSeasonDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SeasonEpisodeAdapter extends TypeAdapter<SeasonEpisode> {
  @override
  final int typeId = 34;

  @override
  SeasonEpisode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SeasonEpisode(
      tmdbId: fields[0] as int,
      episodeNumber: fields[1] as int,
      name: fields[2] as String,
      overview: fields[3] as String?,
      stillPath: fields[4] as String?,
      tmdbRating: fields[5] as double?,
      airDate: fields[6] as DateTime?,
      crew: (fields[7] as List).cast<CrewMember>(),
      runtime: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, SeasonEpisode obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.episodeNumber)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.overview)
      ..writeByte(4)
      ..write(obj.stillPath)
      ..writeByte(5)
      ..write(obj.tmdbRating)
      ..writeByte(6)
      ..write(obj.airDate)
      ..writeByte(7)
      ..write(obj.crew)
      ..writeByte(8)
      ..write(obj.runtime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeasonEpisodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TvEpisodeDetailAdapter extends TypeAdapter<TvEpisodeDetail> {
  @override
  final int typeId = 32;

  @override
  TvEpisodeDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TvEpisodeDetail(
      tmdbId: fields[0] as int,
      showId: fields[1] as int,
      showName: fields[2] as String,
      seasonNumber: fields[3] as int,
      episodeNumber: fields[4] as int,
      name: fields[5] as String,
      overview: fields[6] as String?,
      stillPath: fields[7] as String?,
      airDate: fields[8] as DateTime?,
      tmdbRating: fields[9] as double?,
      voteCount: fields[10] as int?,
      guestStars: (fields[11] as List).cast<CastMember>(),
      crew: (fields[12] as List).cast<CrewMember>(),
      lastUpdated: fields[13] as DateTime?,
      runtime: fields[15] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, TvEpisodeDetail obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.showId)
      ..writeByte(2)
      ..write(obj.showName)
      ..writeByte(3)
      ..write(obj.seasonNumber)
      ..writeByte(4)
      ..write(obj.episodeNumber)
      ..writeByte(5)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.overview)
      ..writeByte(7)
      ..write(obj.stillPath)
      ..writeByte(8)
      ..write(obj.airDate)
      ..writeByte(9)
      ..write(obj.tmdbRating)
      ..writeByte(10)
      ..write(obj.voteCount)
      ..writeByte(11)
      ..write(obj.guestStars)
      ..writeByte(12)
      ..write(obj.crew)
      ..writeByte(13)
      ..write(obj.lastUpdated)
      ..writeByte(14)
      ..write(obj._mainCast)
      ..writeByte(15)
      ..write(obj.runtime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvEpisodeDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
