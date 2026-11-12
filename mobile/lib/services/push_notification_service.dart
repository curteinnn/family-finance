import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/network/api_exception.dart';
import '../features/notifications/data/notifications_repository.dart';

const _channel = AndroidNotificationChannel(
  'family_finance_transactions',
  'Transaksi Family Finance',
  description: 'Pemberitahuan transfer dan pengeluaran keluarga.',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  final Set<Future<void>> _pendingRegistrations = {};
  Future<void> Function(Map<String, dynamic>)? _onOpened;
  NotificationsRepository? _notifications;
  String? _currentToken;

  Future<void> initialize({
    required NotificationsRepository notifications,
    required Future<void> Function(Map<String, dynamic>) onOpened,
  }) async {
    if (!Platform.isAndroid) return;
    _notifications = notifications;
    _onOpened = onOpened;

    await Firebase.initializeApp();
    final messaging = FirebaseMessaging.instance;
    _messaging = messaging;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;

    await _tokenSubscription?.cancel();
    _tokenSubscription = messaging.onRegistered.listen((token) {
      final registration = _registerToken(token);
      _pendingRegistrations.add(registration);
      unawaited(
        registration.whenComplete(() {
          _pendingRegistrations.remove(registration);
        }),
      );
    });
    await messaging.register();
    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? 'Family Finance';
      final body = message.notification?.body ?? 'Ada pembaruan transaksi.';
      unawaited(_showLocalNotification(message, title, body));
    });
    await _openedSubscription?.cancel();
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      unawaited(_openData(message.data));
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) await _openData(initialMessage.data);
    final launchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true && payload != null) {
      await _openPayload(payload);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) unawaited(_openPayload(payload));
      },
    );
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_channel);
  }

  Future<void> _registerToken(String token) async {
    final notifications = _notifications;
    if (notifications == null || token.isEmpty) return;
    try {
      await notifications.registerDevice(token);
      _currentToken = token;
      debugPrint('FCM installation registered with backend.');
    } on ApiException catch (error) {
      debugPrint(
        'FCM installation registration failed (HTTP ${error.statusCode ?? 'network'}).',
      );
    } catch (error) {
      debugPrint('FCM installation registration failed: ${error.runtimeType}.');
      // Push setup must not prevent sign-in or normal app use.
    }
  }

  Future<void> unregister() async {
    await _tokenSubscription?.cancel();
    await Future.wait(_pendingRegistrations.toList());
    final notifications = _notifications;
    final token = _currentToken;
    if (notifications != null && token != null) {
      try {
        await notifications.removeDevice(token);
      } catch (_) {
        // Local logout still proceeds if the API is unavailable.
      }
    }
    _notifications = null;
    _currentToken = null;
    final messaging = _messaging;
    if (messaging != null) {
      try {
        await messaging.unregister();
      } catch (_) {
        // A Firebase cleanup error must not block backend logout.
      }
    }
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _openedSubscription = null;
  }

  Future<void> _showLocalNotification(
    RemoteMessage message,
    String title,
    String body,
  ) async {
    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'family_finance_transactions',
          'Transaksi Family Finance',
          channelDescription:
              'Pemberitahuan transfer dan pengeluaran keluarga.',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _openPayload(String payload) async {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) await _openData(Map<String, dynamic>.from(decoded));
    } on FormatException {
      // Ignore notifications without a valid transaction payload.
    }
  }

  Future<void> _openData(Map<String, dynamic> data) async {
    if (data['type'] is String && data['transactionId'] is String) {
      await _onOpened?.call(data);
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
