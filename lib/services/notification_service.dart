import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showBudgetAlert(String category, double overspendAmount) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      importance: Importance.max,
      priority: Priority.high,
      color: Colors.red,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await notificationsPlugin.show(
      0,
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
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: Colors.orange,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await notificationsPlugin.show(
      1,
      'Budget Warning',
      'You\'ve used ${percentageUsed.toStringAsFixed(0)}% of your $category budget',
      platformChannelSpecifics,
    );
  }
}