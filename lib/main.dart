// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:indayreminder/models/reminder.dart';
import 'package:indayreminder/pages/home_screen.dart';
import 'package:indayreminder/services/reminder_adapter.dart';
import 'package:indayreminder/utils/globals.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  
  await Hive.initFlutter();
  Hive.registerAdapter(ReminderAdapter());
  await Hive.openBox<Reminder>('reminders');
  runApp(MyApp());
}

/// Main App
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Reminder App', theme: lightTheme, darkTheme: dartTheme, home: const ReminderHomePage());
  }
}
