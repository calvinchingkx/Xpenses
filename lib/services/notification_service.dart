import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Budget alert channel (high importance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'budget_alerts',
          'Budget Alerts',
          description: 'Notifications for budget overages',
          importance: Importance.max,
          playSound: true,
        ),
      );

      // Budget warning channel (default importance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'budget_warnings',
          'Budget Warnings',
          description: 'Notifications for budget warnings',
          importance: Importance.defaultImportance,
        ),
      );
    }
  }

  Future<void> showBudgetAlert(String category, double overspendAmount) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Notifications for budget overages',
      importance: Importance.max,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Budget Alert',
      'You\'ve exceeded your $category budget by \$${overspendAmount.toStringAsFixed(2)}',
      platformChannelSpecifics,
    );
  }

  Future<void> showBudgetWarning(String category, double percentageUsed) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'budget_warnings',
      'Budget Warnings',
      channelDescription: 'Notifications for budget warnings',
      importance: Importance.defaultImportance,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Budget Warning',
      'You\'ve used ${percentageUsed.toStringAsFixed(0)}% of your $category budget',
      platformChannelSpecifics,
    );
  }
}