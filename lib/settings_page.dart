import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import 'dart:async';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum TimeMode { range, around, single }

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  TimeMode _mode = TimeMode.range;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _centerTime = const TimeOfDay(hour: 14, minute: 0);
  int _windowHours = 6;
  TimeOfDay _singleTime = const TimeOfDay(hour: 12, minute: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rescheduleNotifications();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _rescheduleNotifications();
    }
  }

  // TODO: This could continually reschedule for the next day every time the user changes a slider/value
  Future<void> _rescheduleNotifications() async {
    // Check if the user has notifications enabled
    final prefs = await SharedPreferences.getInstance();
    final sendNotifications = prefs.getBool('sendNotifications') ?? false;
    if (sendNotifications) {
      await Future.delayed(const Duration(seconds: 2));
      final now = DateTime.now();
      final firstNotificationTime = await getRandomTime(now);
      await flutterLocalNotificationsPlugin.cancelAll();
      await Workmanager().cancelAll();
      // If time has already passed today, schedule for tomorrow
      if (firstNotificationTime.isBefore(now)) {
        firstNotificationTime.add(const Duration(days: 1));
      }
      await scheduleNotification(firstNotificationTime);
    }
  }

  // Note: notifications are rescheduled only when the settings page is closed
  // (dispose) or when the app lifecycle moves to paused. We intentionally
  // do not reschedule on every settings change to avoid unnecessary work.

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mode = TimeMode.values[prefs.getInt('timeMode') ?? 0];
      _startTime = _parseTime(prefs.getString('startTime')) ?? _startTime;
      _endTime = _parseTime(prefs.getString('endTime')) ?? _endTime;
      _centerTime = _parseTime(prefs.getString('centerTime')) ?? _centerTime;
      _windowHours = prefs.getInt('windowHours') ?? _windowHours;
      _singleTime = _parseTime(prefs.getString('singleTime')) ?? _singleTime;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('timeMode', _mode.index);
    prefs.setString('startTime', _formatTime(_startTime));
    prefs.setString('endTime', _formatTime(_endTime));
    prefs.setString('centerTime', _formatTime(_centerTime));
    prefs.setInt('windowHours', _windowHours);
    prefs.setString('singleTime', _formatTime(_singleTime));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}' ;

  TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// Pick a time and update the appropriate field.
  /// Use [isStart] for the range start button, [isEnd] for the range end button.
  /// For center/single picks, leave both false and provide [onPicked] to update the variable.
  Future<void> _pickTime(BuildContext context, TimeOfDay current,
      void Function(TimeOfDay) onPicked, {
        bool isStart = false,
        bool isEnd = false,
      }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_isAfter(_startTime, _endTime)) {
          final temp = _startTime;
          _startTime = _endTime;
          _endTime = temp;
        }
      } else if (isEnd) {
        _endTime = picked;
        if (_isBefore(_endTime, _startTime)) {
          final temp = _startTime;
          _startTime = _endTime;
          _endTime = temp;
        }
      } else {
        // center or single time; let caller update its variable
        onPicked(picked);
      }

      _savePrefs();
    });
  }

  bool _isBefore(TimeOfDay a, TimeOfDay b) =>
      a.hour < b.hour || (a.hour == b.hour && a.minute < b.minute);

  bool _isAfter(TimeOfDay a, TimeOfDay b) =>
      a.hour > b.hour || (a.hour == b.hour && a.minute > b.minute);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); 
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      backgroundColor: colors.primary,
      body: FutureBuilder<int>(
        future: _loadPrefs().then((_) => 0),
        builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Notification Time",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(height: 24),

              // --- RadioGroup Replacement ---
              _buildModeTile(TimeMode.range, "Between two times",
                  "Default: 8:00 AM – 8:00 PM"),
              _buildModeTile(TimeMode.around, "Around a certain time",
                  "Default: 2:00 PM ± 6 hours"),
              _buildModeTile(TimeMode.single, "Single time", "Default: 12:00 PM"),

              const SizedBox(height: 24),
              _buildTimeInputs(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTile(TimeMode mode, String title, String subtitle) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      color: _mode == mode ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: RadioListTile<TimeMode>(
        value: mode,
        groupValue: _mode,
        activeColor: colors.primary,
        onChanged: (value) {
          setState(() {
            _mode = value!;
            _savePrefs();
          });
        },
        title: Text(title, style: TextStyle(color: colors.onSurface)),
        subtitle: Text(subtitle,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
      ),
    );
  }

  Widget _buildTimeInputs(BuildContext context) {
    switch (_mode) {
      case TimeMode.range:
        return _buildRangeInputs(context);
      case TimeMode.around:
        return _buildAroundInputs(context);
      case TimeMode.single:
        return _buildSingleInput(context);
    }
  }

  Widget _buildRangeInputs(BuildContext context) {
    return Column(
      key: const ValueKey("range"),
      children: [
        _timeButton("Start Time", _startTime, (t) => _startTime = t, isStart: true),
        _timeButton("End Time", _endTime, (t) => _endTime = t, isEnd: true),
      ],
    );
  }

  Widget _buildAroundInputs(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey("around"),
      children: [
        _timeButton("Center Time", _centerTime, (t) => _centerTime = t),
        const SizedBox(height: 16),
        Text(
          "± ${_windowHours.toStringAsFixed(1)} hours",
          style: TextStyle(color: colors.onPrimary),
        ),
        Slider(
          value: _windowHours.toDouble(),
          min: 1,
          max: 12,
          divisions: 11,
          activeColor: colors.primaryContainer,
          onChanged: (v) {
            setState(() {
              _windowHours = v.toInt();
              _savePrefs();
            });
          },
        ),
      ],
    );
  }

  Widget _buildSingleInput(BuildContext context) {
    return Column(
      key: const ValueKey("single"),
      children: [
        _timeButton("Notification Time", _singleTime, (t) => _singleTime = t),
      ],
    );
  }

  Widget _timeButton(
      String label,
      TimeOfDay time,
      void Function(TimeOfDay) onPicked, {
        bool isStart = false,
        bool isEnd = false,
      }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
        onPressed: () => _pickTime(context, time, onPicked, isStart: isStart, isEnd: isEnd),
        child: Text(
          "$label: ${time.format(context)}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
