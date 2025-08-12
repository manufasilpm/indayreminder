import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:indayreminder/models/reminder.dart';

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
                return FilterChip(label: Text(dayLabels[i]), selected: selectedDays[i], onSelected: (sel) => setState(() => selectedDays[i] = sel));
              }),
            ),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text("Enable Vibration"), value: vibrationEnabled, onChanged: (v) => setState(() => vibrationEnabled = v)),
            SwitchListTile(title: const Text("Enable Sound"), value: soundEnabled, onChanged: (v) => setState(() => soundEnabled = v)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveReminder, child: const Text("Save Reminder")),
          ],
        ),
      ),
    );
  }
}