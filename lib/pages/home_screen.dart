import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:indayreminder/main.dart';
import 'package:indayreminder/models/reminder.dart';
import 'package:indayreminder/pages/add_screen.dart';
import 'package:timezone/timezone.dart' as tz;

class ReminderHomePage extends StatefulWidget {
  const ReminderHomePage({super.key});
  @override
  State<ReminderHomePage> createState() => _ReminderHomePageState();
}

class _ReminderHomePageState extends State<ReminderHomePage> {
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
  late final Box<Reminder> reminderBox;

  @override
  void initState() {
    super.initState();
    reminderBox = Hive.box<Reminder>('reminders');
    _initAndSchedule();
  }

  DateTime _findNextTime(Reminder reminder) {
    final now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, reminder.fromTime.hour, reminder.fromTime.minute);
    if (start.isBefore(now)) start = start.add(const Duration(days: 1));
    return start;
  }

  Future<void> _initAndSchedule() async {
    await _initNotifications();
    await _rescheduleAll();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(initSettings);
  }

  Future<void> _rescheduleAll() async {
    await notifications.cancelAll();
    for (var reminder in reminderBox.values) {
      await _scheduleReminder(reminder);
    }
  }

  Future<void> _scheduleReminder(Reminder reminder) async {
    final now = DateTime.now();

    DateTime start = DateTime(now.year, now.month, now.day, reminder.fromTime.hour, reminder.fromTime.minute);
    DateTime end = DateTime(now.year, now.month, now.day, reminder.toTime.hour, reminder.toTime.minute);

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    final totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes <= 0) return;

    final intervalMinutes = (totalMinutes / reminder.reminderCount).floor().clamp(1, totalMinutes);
    final interval = Duration(minutes: intervalMinutes);

    int idCounter = 0;
    for (DateTime t = start; t.isBefore(end) || t.isAtSameMomentAs(end); t = t.add(interval)) {
      final weekdayIndex = t.weekday - 1;
      if (!reminder.days[weekdayIndex]) continue;

      final tzTime = tz.TZDateTime.from(t, tz.local);
      final androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Reminders',
        channelDescription: 'Channel for periodic reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: reminder.sound,
        vibrationPattern: reminder.vibration ? Int64List.fromList([0, 500, 1000, 500]) : null,
      );

      await notifications.zonedSchedule(
        reminder.key.hashCode + idCounter,
        'Reminder',
        reminder.message,
        tzTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      idCounter++;
    }
  }

  void _openAddPage({Reminder? editReminder}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddReminderPage(reminderToEdit: editReminder))).then((_) => _rescheduleAll());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reminders")),
      body: RefreshIndicator(
        onRefresh: _rescheduleAll,
        child: ValueListenableBuilder(
          valueListenable: reminderBox.listenable(),
          builder: (context, Box<Reminder> box, _) {
            if (box.isEmpty) {
              return const Center(child: Text("No reminders added."));
            }
            return ListView.builder(
              itemCount: box.length,
              itemBuilder: (context, index) {
                final reminder = box.getAt(index)!;
                DateTime nextTime = _findNextTime(reminder);
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text(reminder.message),
                    subtitle: Text(
                      "Next: ${TimeOfDay.fromDateTime(nextTime).format(context)} "
                      "| ${reminder.fromTime.format(context)} → ${reminder.toTime.format(context)}",
                    ),
                    onTap: () => _openAddPage(editReminder: reminder),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await reminder.delete();
                        await _rescheduleAll();
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openAddPage(), child: const Icon(Icons.add)),
    );
  }
}
