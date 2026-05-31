import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:trackarino_app/screens/auth/login_screen.dart';
import 'package:trackarino_app/services/auth_service.dart';
import 'package:trackarino_app/services/location_service.dart';
import 'package:trackarino_app/services/notification_service.dart';

void main() {
  testWidgets('Login screen renders Google access entrypoint', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => LocationService()),
          Provider(create: (_) => NotificationService()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('TrackNariño'), findsOneWidget);
    expect(find.text('Bienvenido a tu operación'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
