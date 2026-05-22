import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openAppDatabaseConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final dbFolder = Directory(p.join(dir.path, 'offline'));
    if (!dbFolder.existsSync()) {
      dbFolder.createSync(recursive: true);
    }
    return NativeDatabase(
      File(p.join(dbFolder.path, 'tracknarino_sync.sqlite')),
    );
  });
}

Future<void> configureAppDatabasePragmas(GeneratedDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = ON');
  await db.customStatement('PRAGMA journal_mode = WAL');
}
