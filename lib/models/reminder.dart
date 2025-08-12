import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Reminder extends HiveObject {
  String message;
  TimeOfDay fromTime;
  TimeOfDay toTime;
  int reminderCount;
  List<bool> days; // Mon=0 .. Sun=6
  bool vibration;
  bool sound;

  Reminder({
    required this.message,
    required this.fromTime,
    required this.toTime,
    required this.reminderCount,
    required this.days,
    required this.vibration,
    required this.sound,
  });
}