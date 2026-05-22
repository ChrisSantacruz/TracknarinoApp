import 'package:drift/drift.dart';

import 'app_database_connection.dart';

part 'app_database.g.dart';

class OutboundQueueItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientEventId => text().unique()();
  TextColumn get operationType => text()();
  TextColumn get method => text()();
  TextColumn get endpoint => text()();
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get clientTimestamp => dateTime()();
  IntColumn get sequence => integer().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  TextColumn get serverAckJson => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(100))();
  BoolColumn get requiresFifo => boolean().withDefault(const Constant(false))();
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [OutboundQueueItems, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? openAppDatabaseConnection());

  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    beforeOpen: (details) async {
      await configureAppDatabasePragmas(this);
    },
  );
}
