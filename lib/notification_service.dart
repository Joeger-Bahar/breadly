import 'dart:math';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final List<String> localImages = [
  'assets/images/bread0.jpg',
  'assets/images/bread1.jpg',
  'assets/images/bread2.jpg',
  'assets/images/bread3.jpg',
  'assets/images/bread4.jpg',
];

DateTime getRandomTime(DateTime day) {
  final rand = Random();
  int hour = rand.nextInt(12) + 9; // 9am – 9pm
  int minute = rand.nextInt(60);
  return DateTime(day.year, day.month, day.day, hour, minute);
}

Future<void> scheduleNotification(DateTime dateTime) async {
  final rand = Random();

  final assetPath = localImages[rand.nextInt(localImages.length)];
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
  final file = File('${(await getTemporaryDirectory()).path}/$filename');
  await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  return file.path;
}

/// Schedules tomorrow’s notification at a random time.
Future<void> scheduleTomorrowNotification() async {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  final randomTime = getRandomTime(tomorrow);
  await scheduleNotification(randomTime);
}
