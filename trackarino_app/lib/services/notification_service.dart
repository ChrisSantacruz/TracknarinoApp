import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api_service.dart';
import '../config/api_config.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _firebaseMessaging;
  bool _initialized = false;
  
  // Callback para manejar la acción cuando se toca una notificación
  Function(RemoteMessage)? onNotificationTap;

  // Inicializar el servicio
  Future<void> initialize() async {
    if (kIsWeb && Firebase.apps.isEmpty) {
      return;
    }

    _firebaseMessaging ??= FirebaseMessaging.instance;
    final messaging = _firebaseMessaging!;

    // Configurar Firebase Messaging
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurar notificaciones locales
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@drawable/ic_notification');
    
    const DarwinInitializationSettings iOSSettings = 
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        _handleNotificationResponse(details);
      },
    );

    // Manejar notificaciones en primer plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Manejar notificaciones en background que se tocan
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (onNotificationTap != null) {
        onNotificationTap!(message);
      }
    });
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && onNotificationTap != null) {
      onNotificationTap!(initialMessage);
    }
    final token = await messaging.getToken();
    if (token != null) {
      await registerToken(token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      registerToken(token);
    });
    _initialized = true;
  }

  // Manejar mensajes recibidos en primer plano
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'trackarino_channel',
            'Tracknariño Notificaciones',
            channelDescription: 'Canal para notificaciones de Tracknariño',
            importance: Importance.max,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@drawable/ic_notification',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  // Manejar respuesta a notificaciones
  void _handleNotificationResponse(NotificationResponse details) {
    // Aquí podrías manejar la respuesta a una notificación local
    // Por ahora, no hacemos nada específico
  }

  // Obtener el token del dispositivo
  Future<String?> getDeviceToken() async {
    if (!_initialized || _firebaseMessaging == null) return null;
    return await _firebaseMessaging!.getToken();
  }

  Future<void> registerToken(String token) async {
    await ApiService.post(
      '${ApiConfig.notificaciones}/registrar-token',
      {
        'token': token,
        'platform': defaultTargetPlatform.name,
      },
    );
  }

  // Suscribirse a un tema
  Future<void> subscribeTopic(String topic) async {
    if (!_initialized || _firebaseMessaging == null) return;
    await _firebaseMessaging!.subscribeToTopic(topic);
  }

  // Cancelar suscripción a un tema
  Future<void> unsubscribeTopic(String topic) async {
    if (!_initialized || _firebaseMessaging == null) return;
    await _firebaseMessaging!.unsubscribeFromTopic(topic);
  }

  // Mostrar una notificación local
  Future<void> showLocalNotification({
    required String title,
    required String body,
    required int id,
    String? payload,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'trackarino_channel',
          'Tracknariño Notificaciones',
          channelDescription: 'Canal para notificaciones de Tracknariño',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
} 