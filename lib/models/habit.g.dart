// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HabitAdapter extends TypeAdapter<Habit> {
  @override
  final int typeId = 1;

  @override
  Habit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Habit(
      id: fields[0] as String,
      title: fields[1] as String,
      category: fields[2] as String,
      colorValue: fields[3] as int,
      iconCode: fields[4] as int,
      completedDates: (fields[5] as List?)?.cast<String>(),
      targetPerDay: fields[6] as int,
      createdAt: fields[7] as DateTime?,
      reminderMinuteOfDay: fields[8] as int?,
      stackedAfterHabitId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Habit obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.iconCode)
      ..writeByte(5)
      ..write(obj.completedDates)
      ..writeByte(6)
      ..write(obj.targetPerDay)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.reminderMinuteOfDay)
      ..writeByte(9)
      ..write(obj.stackedAfterHabitId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
