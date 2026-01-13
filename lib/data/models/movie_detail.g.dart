// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_detail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CastMemberAdapter extends TypeAdapter<CastMember> {
  @override
  final int typeId = 27;

  @override
  CastMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CastMember(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      profilePath: fields[2] as String?,
      character: fields[3] as String,
      order: fields[4] as int,
      isFollowed: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CastMember obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.profilePath)
      ..writeByte(3)
      ..write(obj.character)
      ..writeByte(4)
      ..write(obj.order)
      ..writeByte(5)
      ..write(obj.isFollowed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastMemberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CrewMemberAdapter extends TypeAdapter<CrewMember> {
  @override
  final int typeId = 28;

  @override
  CrewMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CrewMember(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      profilePath: fields[2] as String?,
      job: fields[3] as String,
      department: fields[4] as String,
      isFollowed: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CrewMember obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.profilePath)
      ..writeByte(3)
      ..write(obj.job)
      ..writeByte(4)
      ..write(obj.department)
      ..writeByte(5)
      ..write(obj.isFollowed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrewMemberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MovieDetailAdapter extends TypeAdapter<MovieDetail> {
  @override
  final int typeId = 29;

  @override
  MovieDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MovieDetail(
      tmdbId: fields[0] as int,
      title: fields[1] as String,
      posterPath: fields[2] as String?,
      releaseDate: fields[3] as DateTime?,
      runtime: fields[4] as int?,
      synopsis: fields[5] as String,
      tmdbRating: fields[6] as double?,
      popularity: fields[7] as double?,
      cast: (fields[8] as List).cast<CastMember>(),
      crew: (fields[9] as List).cast<CrewMember>(),
      imdbId: fields[10] as String?,
      streamingOptions: (fields[12] as List).cast<StreamingOption>(),
      voteCount: fields[13] as int?,
      lastUpdated: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MovieDetail obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.posterPath)
      ..writeByte(3)
      ..write(obj.releaseDate)
      ..writeByte(4)
      ..write(obj.runtime)
      ..writeByte(5)
      ..write(obj.synopsis)
      ..writeByte(6)
      ..write(obj.tmdbRating)
      ..writeByte(7)
      ..write(obj.popularity)
      ..writeByte(8)
      ..write(obj.cast)
      ..writeByte(9)
      ..write(obj.crew)
      ..writeByte(10)
      ..write(obj.imdbId)
      ..writeByte(12)
      ..write(obj.streamingOptions)
      ..writeByte(13)
      ..write(obj.voteCount)
      ..writeByte(14)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
