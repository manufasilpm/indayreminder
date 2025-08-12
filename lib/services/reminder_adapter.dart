import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:indayreminder/models/reminder.dart';

/// Hive Adapter
class ReminderAdapter extends TypeAdapter<Reminder> {
  @override
  final int typeId = 0;

  @override
  Reminder read(BinaryReader reader) {
    return Reminder(
      message: reader.readString(),
      fromTime: TimeOfDay(hour: reader.readInt(), minute: reader.readInt()),
      toTime: TimeOfDay(hour: reader.readInt(), minute: reader.readInt()),
      reminderCount: reader.readInt(),
      days: List<bool>.from(reader.readList()),
      vibration: reader.readBool(),
      sound: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Reminder obj) {
    writer
      ..writeString(obj.message)
      ..writeInt(obj.fromTime.hour)
      ..writeInt(obj.fromTime.minute)
      ..writeInt(obj.toTime.hour)
      ..writeInt(obj.toTime.minute)
      ..writeInt(obj.reminderCount)
      ..writeList(obj.days)
      ..writeBool(obj.vibration)
      ..writeBool(obj.sound);
  }
}