// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'neighbor_node.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NeighborNodeAdapter extends TypeAdapter<NeighborNode> {
  @override
  final int typeId = 2;

  @override
  NeighborNode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NeighborNode(
      nodeId: fields[0] as String,
      nodeName: fields[1] as String?,
      lastRssi: fields[2] as int,
      lastSeen: fields[3] as DateTime,
      latitude: fields[4] as double?,
      longitude: fields[5] as double?,
      successfulRelays: fields[6] as int,
      failedRelays: fields[7] as int,
      firstSeen: fields[8] as DateTime,
      batteryLevel: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, NeighborNode obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.nodeId)
      ..writeByte(1)
      ..write(obj.nodeName)
      ..writeByte(2)
      ..write(obj.lastRssi)
      ..writeByte(3)
      ..write(obj.lastSeen)
      ..writeByte(4)
      ..write(obj.latitude)
      ..writeByte(5)
      ..write(obj.longitude)
      ..writeByte(6)
      ..write(obj.successfulRelays)
      ..writeByte(7)
      ..write(obj.failedRelays)
      ..writeByte(8)
      ..write(obj.firstSeen)
      ..writeByte(9)
      ..write(obj.batteryLevel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NeighborNodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}