// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stored_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StoredMessageAdapter extends TypeAdapter<StoredMessage> {
  @override
  final int typeId = 0;

  @override
  StoredMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StoredMessage(
      messageId: fields[0] as String,
      senderId: fields[1] as String,
      destinationId: fields[2] as String,
      encryptedContent: fields[3] as String,
      timestamp: fields[4] as DateTime,
      hopCount: fields[5] as int,
      status: fields[6] as MessageStatus,
      isOutgoing: fields[7] as bool,
      decryptedContent: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StoredMessage obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.messageId)
      ..writeByte(1)
      ..write(obj.senderId)
      ..writeByte(2)
      ..write(obj.destinationId)
      ..writeByte(3)
      ..write(obj.encryptedContent)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.hopCount)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.isOutgoing)
      ..writeByte(8)
      ..write(obj.decryptedContent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MessageStatusAdapter extends TypeAdapter<MessageStatus> {
  @override
  final int typeId = 1;

  @override
  MessageStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MessageStatus.sending;
      case 1:
        return MessageStatus.sent;
      case 2:
        return MessageStatus.delivered;
      case 3:
        return MessageStatus.read;
      case 4:
        return MessageStatus.received;
      case 5:
        return MessageStatus.failed;
      default:
        return MessageStatus.sending;
    }
  }

  @override
  void write(BinaryWriter writer, MessageStatus obj) {
    switch (obj) {
      case MessageStatus.sending:
        writer.writeByte(0);
        break;
      case MessageStatus.sent:
        writer.writeByte(1);
        break;
      case MessageStatus.delivered:
        writer.writeByte(2);
        break;
      case MessageStatus.read:
        writer.writeByte(3);
        break;
      case MessageStatus.received:
        writer.writeByte(4);
        break;
      case MessageStatus.failed:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}