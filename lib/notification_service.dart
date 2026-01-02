import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final List<String> localImages = [
  'assets/images/bread0.png',
  'assets/images/bread1.png',
  'assets/images/bread2.png',
  'assets/images/bread3.png',
  'assets/images/bread4.png',
  'assets/images/bread5.png',
  'assets/images/bread6.png',
  'assets/images/bread7.png',
  'assets/images/bread8.png',
  'assets/images/bread9.png',
  'assets/images/bread10.png',
  'assets/images/bread11.png',
  'assets/images/bread12.png',
  'assets/images/bread13.png',
  'assets/images/bread14.png',
  'assets/images/bread15.png',
  'assets/images/bread16.png',
  'assets/images/bread17.png',
  'assets/images/bread18.png',
  'assets/images/bread19.png',
  'assets/images/bread20.png',
  'assets/images/bread21.png',
  'assets/images/bread22.png',
  'assets/images/bread23.png',
  'assets/images/bread24.png',
  'assets/images/bread25.png',
  'assets/images/bread26.png',
  'assets/images/bread27.png',
  'assets/images/bread28.png',
  'assets/images/bread29.png',
  'assets/images/bread30.png',
  'assets/images/bread31.png',
  'assets/images/bread32.png',
  'assets/images/bread33.png',
  'assets/images/bread34.png',
  'assets/images/bread35.png',
  'assets/images/bread36.png',
  'assets/images/bread37.png',
  'assets/images/bread38.png',
  'assets/images/bread39.png',
  'assets/images/bread40.png',
  'assets/images/bread41.png',
  'assets/images/bread42.png',
  'assets/images/bread43.png',
  'assets/images/bread44.png',
  'assets/images/bread45.png',
  'assets/images/bread46.png',
  'assets/images/bread47.png',
  'assets/images/bread48.png',
  'assets/images/bread49.png',
];

Future<DateTime> getRandomTime(DateTime now, [bool forToday = false]) async {
  //final prefs = await SharedPreferences.getInstance();
  //final mode = prefs.getInt('timeMode') ?? 0;
  final rand = Random();

  forToday = forToday && now.hour < 20; // Ensure we only use forToday if before 8pm

  DateTime makeTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  // Schedule for a random time between 8 am and 8 pm, or now and 8 pm today
  final start = forToday == true
      ? now.add(const Duration(minutes: 5)) // Start 5 minute from now
      : makeTime('08:00');
  final end = makeTime('20:00');

  final diffMinutes = end.difference(start).inMinutes;
  final minuteOffset = rand.nextInt(diffMinutes + 1);
  return Future.value(start.add(Duration(minutes: minuteOffset)));

  // if (mode == 0) {
  //   final start = makeTime(prefs.getString('startTime') ?? '08:00');
  //   final end = makeTime(prefs.getString('endTime') ?? '20:00');

  //   final diffMinutes = end.difference(start).inMinutes;
  //   final minuteOffset = rand.nextInt(diffMinutes + 1);
  //   return Future.value(start.add(Duration(minutes: minuteOffset)));
  // }

  // if (mode == 1) {
  //   final center = makeTime(prefs.getString('centerTime') ?? '14:00');
  //   final windowHours = prefs.getInt('windowHours') ?? 6.0;
  //   final minTime = center.subtract(Duration(minutes: (windowHours * 60 / 2).round()));
  //   final maxTime = center.add(Duration(minutes: (windowHours * 60 / 2).round())).subtract(const Duration(minutes: 1));

  //   final diffMinutes = maxTime.difference(minTime).inMinutes;
  //   final minuteOffset = rand.nextInt(diffMinutes + 1);
  //   return Future.value(minTime.add(Duration(minutes: minuteOffset)));
  // }

  // if (mode == 2) {
  //   final single = makeTime(prefs.getString('singleTime') ?? '12:00');
  //   return Future.value(single);
  // }


  // return Future.value(DateTime(day.year, day.month, day.day, 12, 0));
}

@pragma('vm:entry-point')
Future<void> scheduleNotification(DateTime dateTime) async {
  final rand = Random();

  final assetPath = localImages[rand.nextInt(50)];
  final fileName = assetPath.split('/').last;
  final imagePath = await _copyAssetImageToFile(assetPath, fileName);

  final styleInfo = BigPictureStyleInformation(
    FilePathAndroidBitmap(imagePath),
    hideExpandedLargeIcon: true,
    contentTitle: "Bread!",
    summaryText: '',
  );

  final androidDetails = AndroidNotificationDetails(
    'bread_image_channel_v2',
    'Bread Images',
    channelDescription: "Daily random bread image",
    importance: Importance.max,
    priority: Priority.high,
    largeIcon: FilePathAndroidBitmap(imagePath),
    styleInformation: styleInfo,
  );

  final notificationDetails = NotificationDetails(android: androidDetails);

  final tzDateTime = tz.TZDateTime.from(
    dateTime,
    tz.getLocation('America/Denver'),
  );

  print("Scheduling notification for $tzDateTime");

  final id = rand.nextInt(1 << 31);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Bread!',
    '',
    tzDateTime,
    notificationDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

Future<String> _copyAssetImageToFile(String assetPath, String filename) async {
  final byteData = await rootBundle.load(assetPath);
  // Use a unique filename so multiple scheduled notifications don't overwrite
  // the same file when copying assets to the temp directory during debugging.
  final uniqueSuffix = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';
  final safeFilename = '${uniqueSuffix}_$filename';
  final file = File('${(await getTemporaryDirectory()).path}/$safeFilename');
  await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  return file.path;
}

/// Schedules tomorrow’s notification at a random time.
@pragma('vm:entry-point')
Future<void> scheduleTomorrowNotification() async {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final randomTime = await getRandomTime(tomorrow);
  await scheduleNotification(randomTime);
}

/// Schedules the next upcoming notification at a random time.
///
/// Picks a random time on the current day between 8:00 and 7:59. If that
/// time is already in the past (or within one minute from now), the function
/// schedules the notification for the same random time on the next day. This
/// makes Workmanager's daily callback idempotent and avoids an off-by-one gap
/// where the day after the user enables notifications is left empty.
// If `forToday` is true, the function will use now->8pm instead of 8am->8pm for the random time
@pragma('vm:entry-point')
Future<void> scheduleNextNotification([bool forToday = false]) async {
  final now = DateTime.now();
  var candidate = await getRandomTime(now, forToday);

  // If the candidate time is earlier than (or very near) now, use tomorrow.
  if (!candidate.isAfter(now.add(const Duration(minutes: 1)))) {
    candidate = candidate.add(const Duration(days: 1));
  }

  print('Scheduling next notification for $candidate (now=$now)');
  await scheduleNotification(candidate);
}

/// Debug helper: schedule a notification every hour for [hours] hours.
///
/// This schedules [hours] one-off notifications starting at [start] (or now
/// if not provided), spaced exactly one hour apart. Useful when debugging
/// notification behavior without waiting a full day. Each scheduled notification
/// will copy the chosen asset to a uniquely named temp file to avoid overwrites.
@pragma('vm:entry-point')
Future<void> scheduleHourlyDebug({int hours = 24, DateTime? start}) async {
  final begin = start ?? DateTime.now();
  for (var i = 0; i < hours; i++) {
    final scheduledTime = begin.add(Duration(minutes: i + 1));
    // scheduleNotification will pick a random image and copy it to a unique file
    await scheduleNotification(scheduledTime);
  }
}
