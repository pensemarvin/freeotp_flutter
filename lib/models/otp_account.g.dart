// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OTPAccountAdapter extends TypeAdapter<OTPAccount> {
  @override
  final int typeId = 0;

  @override
  OTPAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OTPAccount(
      id: fields[0] as String,
      issuer: fields[1] as String,
      name: fields[2] as String,
      secret: fields[3] as String,
      digits: fields[4] == null ? 6 : fields[4] as int,
      period: fields[5] == null ? 30 : fields[5] as int,
      type: fields[6] == null ? OTPType.TOTP : fields[6] as OTPType,
      algorithm: fields[7] == null ? 'sha1' : fields[7] as String,
      addedDate: fields[8] as int?,
      counter: fields[9] == null ? 0 : fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OTPAccount obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.issuer)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.secret)
      ..writeByte(4)
      ..write(obj.digits)
      ..writeByte(5)
      ..write(obj.period)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.algorithm)
      ..writeByte(8)
      ..write(obj.addedDate)
      ..writeByte(9)
      ..write(obj.counter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OTPAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OTPTypeAdapter extends TypeAdapter<OTPType> {
  @override
  final int typeId = 1;

  @override
  OTPType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OTPType.TOTP;
      case 1:
        return OTPType.HOTP;
      default:
        return OTPType.TOTP;
    }
  }

  @override
  void write(BinaryWriter writer, OTPType obj) {
    switch (obj) {
      case OTPType.TOTP:
        writer.writeByte(0);
        break;
      case OTPType.HOTP:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OTPTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
