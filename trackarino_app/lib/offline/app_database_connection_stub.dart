import 'package:drift/drift.dart';

QueryExecutor openAppDatabaseConnection() {
  throw UnsupportedError(
    'Offline database is only supported on mobile, desktop, and web targets.',
  );
}

Future<void> configureAppDatabasePragmas(GeneratedDatabase db) async {}
