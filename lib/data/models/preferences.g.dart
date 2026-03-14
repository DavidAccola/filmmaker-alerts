// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PreferencesAdapter extends TypeAdapter<Preferences> {
  @override
  final int typeId = 2;

  @override
  Preferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Preferences(
      notifyTheatre: fields[0] as bool,
      notifyStreaming: fields[1] as bool,
      scheduleTime: fields[2] as String,
      defaultDepartments: (fields[3] as List).cast<String>(),
      notifyPhysical: fields[4] as bool,
      notifyTV: fields[5] as bool,
      pretendToday: fields[6] as String?,
      includeCollectionsInMovieSearch: fields[7] as bool,
      useGridView: fields[8] as bool?,
      homeSortOrder: fields[9] as String?,
      groupByType: fields[10] as bool?,
      allRolesSelected: fields[11] as bool?,
      allReleaseTypesSelected: fields[12] as bool?,
      autoFollowNewRoles: fields[13] as bool?,
      lastCheckTime: fields[14] as String?,
      lastViewedHistoryTime: fields[15] as String?,
      movieDetailsPreference: fields[16] as String?,
      defaultTvNotificationPrefs: fields[17] as TvNotificationPreferences?,
      notifyPersonTvEpisodes: fields[18] as bool?,
      useDarkMode: fields[19] as bool?,
      hidePopularityInDetails: fields[20] as bool?,
      hideRatingsInDetails: fields[21] as bool?,
      streamingCountry: fields[22] as String?,
      reduceAnimations: fields[23] as bool?,
      watchlistSortOrder: fields[24] as String?,
      watchlistUseListView: fields[25] == null ? false : fields[25] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Preferences obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.notifyTheatre)
      ..writeByte(1)
      ..write(obj.notifyStreaming)
      ..writeByte(2)
      ..write(obj.scheduleTime)
      ..writeByte(3)
      ..write(obj.defaultDepartments)
      ..writeByte(4)
      ..write(obj.notifyPhysical)
      ..writeByte(5)
      ..write(obj.notifyTV)
      ..writeByte(6)
      ..write(obj.pretendToday)
      ..writeByte(7)
      ..write(obj.includeCollectionsInMovieSearch)
      ..writeByte(8)
      ..write(obj.useGridView)
      ..writeByte(9)
      ..write(obj.homeSortOrder)
      ..writeByte(10)
      ..write(obj.groupByType)
      ..writeByte(11)
      ..write(obj.allRolesSelected)
      ..writeByte(12)
      ..write(obj.allReleaseTypesSelected)
      ..writeByte(13)
      ..write(obj.autoFollowNewRoles)
      ..writeByte(14)
      ..write(obj.lastCheckTime)
      ..writeByte(15)
      ..write(obj.lastViewedHistoryTime)
      ..writeByte(16)
      ..write(obj.movieDetailsPreference)
      ..writeByte(17)
      ..write(obj.defaultTvNotificationPrefs)
      ..writeByte(18)
      ..write(obj.notifyPersonTvEpisodes)
      ..writeByte(19)
      ..write(obj.useDarkMode)
      ..writeByte(20)
      ..write(obj.hidePopularityInDetails)
      ..writeByte(21)
      ..write(obj.hideRatingsInDetails)
      ..writeByte(22)
      ..write(obj.streamingCountry)
      ..writeByte(23)
      ..write(obj.reduceAnimations)
      ..writeByte(24)
      ..write(obj.watchlistSortOrder)
      ..writeByte(25)
      ..write(obj.watchlistUseListView);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
