// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contributor_detail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ContributorRoleAdapter extends TypeAdapter<ContributorRole> {
  @override
  final int typeId = 23;

  @override
  ContributorRole read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContributorRole(
      contributorId: fields[0] as int,
      contributorName: fields[1] as String,
      role: fields[2] as String,
      department: fields[3] as String?,
      character: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ContributorRole obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.contributorId)
      ..writeByte(1)
      ..write(obj.contributorName)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.department)
      ..writeByte(4)
      ..write(obj.character);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributorRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StreamingOptionAdapter extends TypeAdapter<StreamingOption> {
  @override
  final int typeId = 24;

  @override
  StreamingOption read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StreamingOption(
      providerId: fields[0] as String,
      providerName: fields[1] as String,
      logoPath: fields[2] as String?,
      type: fields[3] as StreamingType,
      price: fields[4] as String?,
      deepLink: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, StreamingOption obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.providerId)
      ..writeByte(1)
      ..write(obj.providerName)
      ..writeByte(2)
      ..write(obj.logoPath)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.price)
      ..writeByte(5)
      ..write(obj.deepLink);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingOptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkAdapter extends TypeAdapter<Work> {
  @override
  final int typeId = 25;

  @override
  Work read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Work(
      tmdbId: fields[0] as int,
      title: fields[1] as String,
      posterPath: fields[2] as String?,
      releaseDate: fields[3] as DateTime?,
      type: fields[4] as WorkType,
      tmdbRating: fields[5] as double?,
      popularity: fields[6] as double?,
      releaseType: fields[7] as ReleaseType?,
      contributorRoles: (fields[8] as List).cast<ContributorRole>(),
      streamingOptions: (fields[9] as List).cast<StreamingOption>(),
      imdbId: fields[10] as String?,
      episodeNumber: fields[11] as int?,
      seasonNumber: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Work obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.posterPath)
      ..writeByte(3)
      ..write(obj.releaseDate)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.tmdbRating)
      ..writeByte(6)
      ..write(obj.popularity)
      ..writeByte(7)
      ..write(obj.releaseType)
      ..writeByte(8)
      ..write(obj.contributorRoles)
      ..writeByte(9)
      ..write(obj.streamingOptions)
      ..writeByte(10)
      ..write(obj.imdbId)
      ..writeByte(11)
      ..write(obj.episodeNumber)
      ..writeByte(12)
      ..write(obj.seasonNumber);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContributorDetailAdapter extends TypeAdapter<ContributorDetail> {
  @override
  final int typeId = 26;

  @override
  ContributorDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ContributorDetail(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      profilePath: fields[2] as String?,
      imdbId: fields[3] as String?,
      type: fields[4] as ContributorType,
      upcomingWorks: (fields[5] as List).cast<Work>(),
      latestReleases: (fields[6] as List).cast<Work>(),
      biggestHits: (fields[7] as List).cast<Work>(),
      lastUpdated: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, ContributorDetail obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.profilePath)
      ..writeByte(3)
      ..write(obj.imdbId)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.upcomingWorks)
      ..writeByte(6)
      ..write(obj.latestReleases)
      ..writeByte(7)
      ..write(obj.biggestHits)
      ..writeByte(8)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributorDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkTypeAdapter extends TypeAdapter<WorkType> {
  @override
  final int typeId = 20;

  @override
  WorkType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WorkType.movie;
      case 1:
        return WorkType.tvShow;
      case 2:
        return WorkType.tvEpisode;
      default:
        return WorkType.movie;
    }
  }

  @override
  void write(BinaryWriter writer, WorkType obj) {
    switch (obj) {
      case WorkType.movie:
        writer.writeByte(0);
        break;
      case WorkType.tvShow:
        writer.writeByte(1);
        break;
      case WorkType.tvEpisode:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReleaseTypeAdapter extends TypeAdapter<ReleaseType> {
  @override
  final int typeId = 21;

  @override
  ReleaseType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReleaseType.theatrical;
      case 1:
        return ReleaseType.streaming;
      case 2:
        return ReleaseType.digital;
      case 3:
        return ReleaseType.physical;
      default:
        return ReleaseType.theatrical;
    }
  }

  @override
  void write(BinaryWriter writer, ReleaseType obj) {
    switch (obj) {
      case ReleaseType.theatrical:
        writer.writeByte(0);
        break;
      case ReleaseType.streaming:
        writer.writeByte(1);
        break;
      case ReleaseType.digital:
        writer.writeByte(2);
        break;
      case ReleaseType.physical:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class StreamingTypeAdapter extends TypeAdapter<StreamingType> {
  @override
  final int typeId = 22;

  @override
  StreamingType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return StreamingType.subscription;
      case 1:
        return StreamingType.rent;
      case 2:
        return StreamingType.buy;
      case 3:
        return StreamingType.free;
      default:
        return StreamingType.subscription;
    }
  }

  @override
  void write(BinaryWriter writer, StreamingType obj) {
    switch (obj) {
      case StreamingType.subscription:
        writer.writeByte(0);
        break;
      case StreamingType.rent:
        writer.writeByte(1);
        break;
      case StreamingType.buy:
        writer.writeByte(2);
        break;
      case StreamingType.free:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamingTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
