import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';

const String workManagerTaskName = 'scheduleNotifications';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == workManagerTaskName) {
      // Init notifications plugin in background isolate
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      // Schedule tomorrow’s one random notification
      await scheduleTomorrowNotification();
    }
    return Future.value(true);
  });
}

// TODO: Tell users to exclude breadly from battery optimizations

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Denver'));

  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getBool('sendNotifications') ?? false;

  runApp(
    ChangeNotifierProvider(
      create: (_) => MyAppState(sendNotifications: saved),
      child: MyApp(),
    ),
  );

  await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.requestExactAlarmsPermission();
  await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.requestNotificationsPermission();
}


class MyAppState extends ChangeNotifier {
  bool sendNotifications;

  MyAppState({required this.sendNotifications});

  Future<void> toggleSendNotifications() async {
    sendNotifications = !sendNotifications;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sendNotifications', sendNotifications);

    if (sendNotifications) {
      // First notification
      await scheduleNotification(DateTime.now().add(const Duration(seconds: 3)));

      // Start notification cycle
      Workmanager().registerPeriodicTask(
        workManagerTaskName,
        workManagerTaskName,
        frequency: const Duration(days: 1),
        initialDelay: const Duration(days: 1),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(
          networkType: NetworkType.notRequired, // TODO: Might need to change this when push notif added
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
    } else {
      // Stop notification cycle
      await Workmanager().cancelAll();
      await flutterLocalNotificationsPlugin.cancelAll();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: Colors.brown,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Breadly',
      theme: ThemeData(
        colorScheme: colors,
        useMaterial3: true,
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.primary; // active thumb = brown
            }
            return colors.surfaceContainerHighest; // inactive thumb = tan
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colors.primaryContainer; // lighter brown track
            }
            return colors.onPrimaryContainer; // faint gray/tan when off
          }),
        ),
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
    const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    var theme = Theme.of(context);
    var colors = theme.colorScheme;

    var titleTextStyle = theme.textTheme.displayLarge!.copyWith(
      fontWeight: FontWeight.bold,
      color: colors.onPrimary,
    );

    return Scaffold(
      body: Container(
        color: colors.primary,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Breadly", style: titleTextStyle),
              ElevatedButton(
                onPressed: () {
                  scheduleNotification(DateTime.now().add(const Duration(seconds: 3)));
                },
                child: const Text("Get Bread"),
              ),
              LabeledSwitch(
                label: "Send Notifications",
                value: appState.sendNotifications,
                onChanged: (_) => appState.toggleSendNotifications(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LabeledSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const LabeledSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge!.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        SizedBox(height: 8),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}