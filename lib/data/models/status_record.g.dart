// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StatusRecordAdapter extends TypeAdapter<StatusRecord> {
  @override
  final int typeId = 43;

  @override
  StatusRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StatusRecord(
      status: fields[0] as WatchStatus,
      setAt: fields[1] as DateTime,
      watchDates: (fields[2] as List?)?.cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, StatusRecord obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.status)
      ..writeByte(1)
      ..write(obj.setAt)
      ..writeByte(2)
      ..write(obj.watchDates);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WatchStatusAdapter extends TypeAdapter<WatchStatus> {
  @override
  final int typeId = 44;

  @override
  WatchStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WatchStatus.wantToWatch;
      case 1:
        return WatchStatus.inProgress;
      case 2:
        return WatchStatus.watched;
      case 3:
        return WatchStatus.dnf;
      default:
        return WatchStatus.wantToWatch;
    }
  }

  @override
  void write(BinaryWriter writer, WatchStatus obj) {
    switch (obj) {
      case WatchStatus.wantToWatch:
        writer.writeByte(0);
        break;
      case WatchStatus.inProgress:
        writer.writeByte(1);
        break;
      case WatchStatus.watched:
        writer.writeByte(2);
        break;
      case WatchStatus.dnf:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
