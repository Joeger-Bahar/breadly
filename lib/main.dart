import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import 'notification_service.dart';
import 'settings_page.dart';
import 'credits_page.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

const String workManagerTaskName = 'scheduleNotifications';
// Toggle this to true while debugging to have Workmanager schedule hourly
// tasks instead of daily. Set back to false for production behavior.
const bool kDebugScheduleHourly = true;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Ensure Flutter bindings are available in the background isolate so
    // platform channels (rootBundle, path_provider) work when copying assets
    // and initializing plugins.
    WidgetsFlutterBinding.ensureInitialized();
    if (task == workManagerTaskName) {
      // Initialize timezone data in the background isolate so tz.TZDateTime works
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Denver'));

      // Init notifications plugin in background isolate using the shared instance
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      // Schedule the next upcoming notification (today if still possible,
      // otherwise tomorrow). This avoids leaving a gap when the app is toggled
      // on late in the day.
      await scheduleNextNotification();
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

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
  final saved = prefs.getBool('sendNotifications') ?? true;

  runApp(
    ChangeNotifierProvider(
      create: (_) => MyAppState(sendNotifications: saved),
      child: const MyApp(),
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
      const id = "daily_bread_notification";

      // Schedule notification for today
      scheduleNextNotification(true); // Want to try and schedule the notification for today if possible

      Workmanager().registerPeriodicTask(
        id,
        workManagerTaskName,
        frequency: const Duration(days: 1),
        initialDelay: const Duration(minutes: 1),
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
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
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
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  static const MethodChannel _batteryChannel = MethodChannel('com.example.breadly/battery');

  bool _didShowBatteryDialog = false;
  bool _batteryExcluded = false; // true when the app is excluded from battery optimizations
  bool _hideBatteryButton = false; // true when user chose to hide the reminder

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndShowBatteryDialog();
    _loadBatteryPrefsAndStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check battery exclusion status when the app returns to foreground
      _loadBatteryPrefsAndStatus();
    }
  }

  Future<void> _loadBatteryPrefsAndStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final excludedPref = prefs.getBool('batteryExcluded') ?? false;
    final hiddenPref = prefs.getBool('hideBatteryOptButton') ?? false;

    var isExcluded = excludedPref;

    if (!isExcluded) {
      try {
        if (!Platform.isAndroid) {
          // Battery optimization concept is Android-specific; treat as excluded on other platforms
          isExcluded = true;
        } else {
          final result = await _batteryChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
          isExcluded = result ?? false;
        }
      } catch (e) {
        // If check fails, leave as not excluded — user can mark manually from the menu
      }
    }

    if (isExcluded != excludedPref) {
      await prefs.setBool('batteryExcluded', isExcluded);
    }

    setState(() {
      _batteryExcluded = isExcluded;
      _hideBatteryButton = hiddenPref;
    });
  }

  Future<void> _setBatteryExcluded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('batteryExcluded', value);
    setState(() {
      _batteryExcluded = value;
    });
  }

  Future<void> _setHideBatteryButton(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hideBatteryOptButton', value);
    setState(() {
      _hideBatteryButton = value;
    });
  }

  Future<void> _checkAndShowBatteryDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seenBatteryOptDialog') ?? false;
    if (!seen && !_didShowBatteryDialog) {
      // Delay a frame so context is available for showDialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBatteryDialog();
      });
      _didShowBatteryDialog = true;
      await prefs.setBool('seenBatteryOptDialog', true);
    }
  }

  void _showBatteryDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Battery optimization'),
          content: const Text(
              'To ensure Breadly can schedule notifications reliably, please exclude it from battery optimizations.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                _openBatteryOptimizationSettings();
              },
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );
  }

  void _openBatteryOptimizationSettings() {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      intent.launch();
    } catch (e) {
      // Fallback: open app-specific battery settings where possible
      try {
        final intent = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:com.example.breadly',
        );
        intent.launch();
      } catch (e) {
        // ignore - couldn't launch intent
      }
    }
  }

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
      appBar: AppBar(
        backgroundColor: colors.primary,
        actions: [
          if (!_batteryExcluded && !_hideBatteryButton)
            PopupMenuButton<String>(
              icon: Icon(Icons.battery_alert, color: colors.onPrimary),
              iconSize: 32,
              onSelected: (value) {
                if (value == 'open') {
                  _openBatteryOptimizationSettings();
                } else if (value == 'excluded') {
                  _setBatteryExcluded(true);
                } else if (value == 'hide') {
                  _setHideBatteryButton(true);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'open', child: Text('Open battery optimization settings')),
                const PopupMenuItem(value: 'excluded', child: Text("I've excluded Breadly")),
                const PopupMenuItem(value: 'hide', child: Text('Hide this reminder')),
              ],
            ),

          IconButton(
            iconSize: 32,
            color: colors.onPrimary,
            icon: const Icon(Icons.groups),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreditsPage()),
              );
            },
          ),
        ],
      ),
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
    var colors = theme.colorScheme;

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
        const SizedBox(height: 8),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return Icon(Icons.check, size: 16, color: colors.onPrimary);
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}