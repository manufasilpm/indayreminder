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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  
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
    return MaterialApp(
      title: 'Reminder App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
      ),
      home: const ReminderHomePage(),
    );
  }
}

/// Home Page
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
    _checkAndRequestPermissions().then((_) => _initAndSchedule());
  }

  Future<void> _checkAndRequestPermissions() async {
    // Request notification permission (Android 13+)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android)) {
      final notificationStatus = await Permission.notification.request();
      if (notificationStatus.isPermanentlyDenied) {
        _showPermissionDialog(
          "Notification Permission Required",
          "Please enable notifications in app settings",
        );
      }
      
      // Check exact alarm permission
      if (!await Permission.scheduleExactAlarm.isGranted) {
        _showPermissionDialog(
          "Exact Alarm Permission Required",
          "Please enable 'Schedule Exact Alarms' in app settings",
        );
      }
    }
  }

  void _showPermissionDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
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
        vibrationPattern: reminder.vibration ? Int64List.fromList([0, 500, 1000, 500]) :Int64List(0),
      );

      await notifications.zonedSchedule(
        reminder.key.hashCode + idCounter,
        'Reminder',
        reminder.message,
        tzTime,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      idCounter++;
    }
  }

  void _openAddPage({Reminder? editReminder}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddReminderPage(reminderToEdit: editReminder)),
    ).then((_) => _rescheduleAll());
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddPage(),
        child: const Icon(Icons.add),
      ),
    );
  }

  DateTime _findNextTime(Reminder reminder) {
    final now = DateTime.now();
    DateTime start = DateTime(now.year, now.month, now.day, reminder.fromTime.hour, reminder.fromTime.minute);
    if (start.isBefore(now)) start = start.add(const Duration(days: 1));
    return start;
  }
}

/// Add/Edit Reminder Page
class AddReminderPage extends StatefulWidget {
  final Reminder? reminderToEdit;
  const AddReminderPage({super.key, this.reminderToEdit});

  @override
  State<AddReminderPage> createState() => _AddReminderPageState();
}

class _AddReminderPageState extends State<AddReminderPage> {
  TimeOfDay? fromTime;
  TimeOfDay? toTime;
  int reminderCount = 1;
  String message = "";
  List<bool> selectedDays = List.generate(7, (_) => true);
  bool vibrationEnabled = true;
  bool soundEnabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.reminderToEdit != null) {
      final r = widget.reminderToEdit!;
      fromTime = r.fromTime;
      toTime = r.toTime;
      reminderCount = r.reminderCount;
      message = r.message;
      selectedDays = List.from(r.days);
      vibrationEnabled = r.vibration;
      soundEnabled = r.sound;
    }
  }

  Future<void> _pickTime(bool isFrom) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromTime = picked;
        } else {
          toTime = picked;
        }
      });
    }
  }

  void _saveReminder() {
    if (fromTime == null || toTime == null || message.trim().isEmpty || reminderCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }
    if (!selectedDays.contains(true)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one day")));
      return;
    }

    if (widget.reminderToEdit != null) {
      widget.reminderToEdit!
        ..message = message.trim()
        ..fromTime = fromTime!
        ..toTime = toTime!
        ..reminderCount = reminderCount
        ..days = selectedDays
        ..vibration = vibrationEnabled
        ..sound = soundEnabled
        ..save();
    } else {
      Hive.box<Reminder>('reminders').add(
        Reminder(
          message: message.trim(),
          fromTime: fromTime!,
          toTime: toTime!,
          reminderCount: reminderCount,
          days: selectedDays,
          vibration: vibrationEnabled,
          sound: soundEnabled,
        ),
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Scaffold(
      appBar: AppBar(title: Text(widget.reminderToEdit == null ? "Add Reminder" : "Edit Reminder")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ListTile(
              title: Text(fromTime == null ? "Select From Time" : "From: ${fromTime!.format(context)}"),
              trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () => _pickTime(true)),
            ),
            ListTile(
              title: Text(toTime == null ? "Select To Time" : "To: ${toTime!.format(context)}"),
              trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () => _pickTime(false)),
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Number of reminders"),
              onChanged: (val) => setState(() => reminderCount = int.tryParse(val) ?? 1),
              controller: TextEditingController(text: reminderCount.toString()),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: "Reminder Message"),
              onChanged: (val) => message = val,
              controller: TextEditingController(text: message),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                return FilterChip(
                  label: Text(dayLabels[i]),
                  selected: selectedDays[i],
                  onSelected: (sel) => setState(() => selectedDays[i] = sel),
                );
              }),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text("Enable Vibration"),
              value: vibrationEnabled,
              onChanged: (v) => setState(() => vibrationEnabled = v),
            ),
            SwitchListTile(
              title: const Text("Enable Sound"),
              value: soundEnabled,
              onChanged: (v) => setState(() => soundEnabled = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveReminder, child: const Text("Save Reminder")),
          ],
        ),
      ),
    );
  }
}
