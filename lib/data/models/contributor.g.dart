// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contributor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TvNotificationPreferencesAdapter
    extends TypeAdapter<TvNotificationPreferences> {
  @override
  final int typeId = 8;

  @override
  TvNotificationPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TvNotificationPreferences(
      seriesPremiere: fields[0] as bool,
      seasonPremieres: fields[1] as bool,
      seasonFinales: fields[2] as bool,
      newEpisodes: fields[3] as bool,
      specials: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TvNotificationPreferences obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.seriesPremiere)
      ..writeByte(1)
      ..write(obj.seasonPremieres)
      ..writeByte(2)
      ..write(obj.seasonFinales)
      ..writeByte(3)
      ..write(obj.newEpisodes)
      ..writeByte(4)
      ..write(obj.specials);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvNotificationPreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LatestWorkAdapter extends TypeAdapter<LatestWork> {
  @override
  final int typeId = 1;

  @override
  LatestWork read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LatestWork(
      title: fields[0] as String,
      releaseYear: fields[1] as String,
      releaseDate: fields[2] as String,
      department: fields[3] as String,
      job: fields[4] as String?,
      posterPath: fields[5] as String?,
      originalReleaseDate: fields[6] as String?,
      originalReleaseType: fields[7] as String?,
      latestReleaseDate: fields[8] as String?,
      latestReleaseType: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LatestWork obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.releaseYear)
      ..writeByte(2)
      ..write(obj.releaseDate)
      ..writeByte(3)
      ..write(obj.department)
      ..writeByte(4)
      ..write(obj.job)
      ..writeByte(5)
      ..write(obj.posterPath)
      ..writeByte(6)
      ..write(obj.originalReleaseDate)
      ..writeByte(7)
      ..write(obj.originalReleaseType)
      ..writeByte(8)
      ..write(obj.latestReleaseDate)
      ..writeByte(9)
      ..write(obj.latestReleaseType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatestWorkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContributorAdapter extends TypeAdapter<Contributor> {
  @override
  final int typeId = 0;

  @override
  Contributor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Contributor(
      tmdbId: fields[0] as int,
      name: fields[1] as String,
      type: fields[2] as ContributorType,
      profilePath: fields[3] as String?,
      notifyForDepartments: (fields[4] as List).cast<String>(),
      availableDepartments: (fields[5] as List).cast<String>(),
      knownFor: fields[6] as String,
      latestWork: fields[7] as LatestWork?,
      followedAt: fields[8] as DateTime?,
      allRolesSelected: fields[9] as bool?,
      tvNotificationPrefs: fields[10] as TvNotificationPreferences?,
      notifyTvEpisodeWork: fields[11] as bool?,
      showStatus: fields[12] as String?,
      totalSeasons: fields[13] as int?,
      nextEpisodeDate: fields[14] as String?,
      imdbId: fields[15] as String?,
      notificationsSnoozed: fields[16] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Contributor obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.profilePath)
      ..writeByte(4)
      ..write(obj.notifyForDepartments)
      ..writeByte(5)
      ..write(obj.availableDepartments)
      ..writeByte(6)
      ..write(obj.knownFor)
      ..writeByte(7)
      ..write(obj.latestWork)
      ..writeByte(8)
      ..write(obj.followedAt)
      ..writeByte(9)
      ..write(obj.allRolesSelected)
      ..writeByte(10)
      ..write(obj.tvNotificationPrefs)
      ..writeByte(11)
      ..write(obj.notifyTvEpisodeWork)
      ..writeByte(12)
      ..write(obj.showStatus)
      ..writeByte(13)
      ..write(obj.totalSeasons)
      ..writeByte(14)
      ..write(obj.nextEpisodeDate)
      ..writeByte(15)
      ..write(obj.imdbId)
      ..writeByte(16)
      ..write(obj.notificationsSnoozed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContributorTypeAdapter extends TypeAdapter<ContributorType> {
  @override
  final int typeId = 7;

  @override
  ContributorType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ContributorType.person;
      case 1:
        return ContributorType.company;
      case 2:
        return ContributorType.movie;
      case 3:
        return ContributorType.collection;
      case 4:
        return ContributorType.tvShow;
      default:
        return ContributorType.person;
    }
  }

  @override
  void write(BinaryWriter writer, ContributorType obj) {
    switch (obj) {
      case ContributorType.person:
        writer.writeByte(0);
        break;
      case ContributorType.company:
        writer.writeByte(1);
        break;
      case ContributorType.movie:
        writer.writeByte(2);
        break;
      case ContributorType.collection:
        writer.writeByte(3);
        break;
      case ContributorType.tvShow:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContributorTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
