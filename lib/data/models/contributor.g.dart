// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contributor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
    );
  }

  @override
  void write(BinaryWriter writer, Contributor obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.allRolesSelected);
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
