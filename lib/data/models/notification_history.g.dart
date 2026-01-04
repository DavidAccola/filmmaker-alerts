// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NotificationReasonAdapter extends TypeAdapter<NotificationReason> {
  @override
  final int typeId = 4;

  @override
  NotificationReason read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationReason(
      contributorId: fields[0] as int,
      contributorName: fields[1] as String,
      department: fields[2] as String,
      job: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationReason obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.contributorId)
      ..writeByte(1)
      ..write(obj.contributorName)
      ..writeByte(2)
      ..write(obj.department)
      ..writeByte(3)
      ..write(obj.job);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationReasonAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationEventAdapter extends TypeAdapter<NotificationEvent> {
  @override
  final int typeId = 5;

  @override
  NotificationEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationEvent(
      releaseType: fields[0] as String,
      releaseDate: fields[1] as String,
      notifiedAt: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, NotificationEvent obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.releaseType)
      ..writeByte(1)
      ..write(obj.releaseDate)
      ..writeByte(2)
      ..write(obj.notifiedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NotificationHistoryEntryAdapter
    extends TypeAdapter<NotificationHistoryEntry> {
  @override
  final int typeId = 3;

  @override
  NotificationHistoryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NotificationHistoryEntry(
      tmdbId: fields[0] as int,
      reasons: (fields[1] as List).cast<NotificationReason>(),
      notificationEvents: (fields[2] as List).cast<NotificationEvent>(),
    );
  }

  @override
  void write(BinaryWriter writer, NotificationHistoryEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.tmdbId)
      ..writeByte(1)
      ..write(obj.reasons)
      ..writeByte(2)
      ..write(obj.notificationEvents);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationHistoryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
