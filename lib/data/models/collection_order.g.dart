// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CollectionOrderAdapter extends TypeAdapter<CollectionOrder> {
  @override
  final int typeId = 49;

  @override
  CollectionOrder read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CollectionOrder(
      collectionId: fields[0] as int,
      movieIds: (fields[1] as List?)?.cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, CollectionOrder obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.collectionId)
      ..writeByte(1)
      ..write(obj.movieIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionOrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
