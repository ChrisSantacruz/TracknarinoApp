import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openAppDatabaseConnection() {
  return WebDatabase('tracknarino_sync');
}

Future<void> configureAppDatabasePragmas(GeneratedDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = ON');
}
