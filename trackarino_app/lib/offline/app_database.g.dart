// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OutboundQueueItemsTable extends OutboundQueueItems
    with TableInfo<$OutboundQueueItemsTable, OutboundQueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboundQueueItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientEventIdMeta = const VerificationMeta(
    'clientEventId',
  );
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
    'client_event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientTimestampMeta = const VerificationMeta(
    'clientTimestamp',
  );
  @override
  late final GeneratedColumn<DateTime> clientTimestamp =
      GeneratedColumn<DateTime>(
        'client_timestamp',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextRetryAt = GeneratedColumn<DateTime>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverAckJsonMeta = const VerificationMeta(
    'serverAckJson',
  );
  @override
  late final GeneratedColumn<String> serverAckJson = GeneratedColumn<String>(
    'server_ack_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _requiresFifoMeta = const VerificationMeta(
    'requiresFifo',
  );
  @override
  late final GeneratedColumn<bool> requiresFifo = GeneratedColumn<bool>(
    'requires_fifo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_fifo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientEventId,
    operationType,
    method,
    endpoint,
    payloadJson,
    status,
    createdAt,
    clientTimestamp,
    sequence,
    attempts,
    nextRetryAt,
    lastError,
    syncedAt,
    serverAckJson,
    priority,
    requiresFifo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbound_queue_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboundQueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
        _clientEventIdMeta,
        clientEventId.isAcceptableOrUnknown(
          data['client_event_id']!,
          _clientEventIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('client_timestamp')) {
      context.handle(
        _clientTimestampMeta,
        clientTimestamp.isAcceptableOrUnknown(
          data['client_timestamp']!,
          _clientTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientTimestampMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('server_ack_json')) {
      context.handle(
        _serverAckJsonMeta,
        serverAckJson.isAcceptableOrUnknown(
          data['server_ack_json']!,
          _serverAckJsonMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('requires_fifo')) {
      context.handle(
        _requiresFifoMeta,
        requiresFifo.isAcceptableOrUnknown(
          data['requires_fifo']!,
          _requiresFifoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboundQueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboundQueueItem(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      clientEventId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}client_event_id'],
          )!,
      operationType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}operation_type'],
          )!,
      method:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}method'],
          )!,
      endpoint:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}endpoint'],
          )!,
      payloadJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload_json'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      clientTimestamp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}client_timestamp'],
          )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      ),
      attempts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}attempts'],
          )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_retry_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      serverAckJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_ack_json'],
      ),
      priority:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}priority'],
          )!,
      requiresFifo:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}requires_fifo'],
          )!,
    );
  }

  @override
  $OutboundQueueItemsTable createAlias(String alias) {
    return $OutboundQueueItemsTable(attachedDatabase, alias);
  }
}

class OutboundQueueItem extends DataClass
    implements Insertable<OutboundQueueItem> {
  final int id;
  final String clientEventId;
  final String operationType;
  final String method;
  final String endpoint;
  final String payloadJson;
  final String status;
  final DateTime createdAt;
  final DateTime clientTimestamp;
  final int? sequence;
  final int attempts;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime? syncedAt;
  final String? serverAckJson;
  final int priority;
  final bool requiresFifo;
  const OutboundQueueItem({
    required this.id,
    required this.clientEventId,
    required this.operationType,
    required this.method,
    required this.endpoint,
    required this.payloadJson,
    required this.status,
    required this.createdAt,
    required this.clientTimestamp,
    this.sequence,
    required this.attempts,
    this.nextRetryAt,
    this.lastError,
    this.syncedAt,
    this.serverAckJson,
    required this.priority,
    required this.requiresFifo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_event_id'] = Variable<String>(clientEventId);
    map['operation_type'] = Variable<String>(operationType);
    map['method'] = Variable<String>(method);
    map['endpoint'] = Variable<String>(endpoint);
    map['payload_json'] = Variable<String>(payloadJson);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['client_timestamp'] = Variable<DateTime>(clientTimestamp);
    if (!nullToAbsent || sequence != null) {
      map['sequence'] = Variable<int>(sequence);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || serverAckJson != null) {
      map['server_ack_json'] = Variable<String>(serverAckJson);
    }
    map['priority'] = Variable<int>(priority);
    map['requires_fifo'] = Variable<bool>(requiresFifo);
    return map;
  }

  OutboundQueueItemsCompanion toCompanion(bool nullToAbsent) {
    return OutboundQueueItemsCompanion(
      id: Value(id),
      clientEventId: Value(clientEventId),
      operationType: Value(operationType),
      method: Value(method),
      endpoint: Value(endpoint),
      payloadJson: Value(payloadJson),
      status: Value(status),
      createdAt: Value(createdAt),
      clientTimestamp: Value(clientTimestamp),
      sequence:
          sequence == null && nullToAbsent
              ? const Value.absent()
              : Value(sequence),
      attempts: Value(attempts),
      nextRetryAt:
          nextRetryAt == null && nullToAbsent
              ? const Value.absent()
              : Value(nextRetryAt),
      lastError:
          lastError == null && nullToAbsent
              ? const Value.absent()
              : Value(lastError),
      syncedAt:
          syncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(syncedAt),
      serverAckJson:
          serverAckJson == null && nullToAbsent
              ? const Value.absent()
              : Value(serverAckJson),
      priority: Value(priority),
      requiresFifo: Value(requiresFifo),
    );
  }

  factory OutboundQueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboundQueueItem(
      id: serializer.fromJson<int>(json['id']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      method: serializer.fromJson<String>(json['method']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      clientTimestamp: serializer.fromJson<DateTime>(json['clientTimestamp']),
      sequence: serializer.fromJson<int?>(json['sequence']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextRetryAt: serializer.fromJson<DateTime?>(json['nextRetryAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      serverAckJson: serializer.fromJson<String?>(json['serverAckJson']),
      priority: serializer.fromJson<int>(json['priority']),
      requiresFifo: serializer.fromJson<bool>(json['requiresFifo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientEventId': serializer.toJson<String>(clientEventId),
      'operationType': serializer.toJson<String>(operationType),
      'method': serializer.toJson<String>(method),
      'endpoint': serializer.toJson<String>(endpoint),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'clientTimestamp': serializer.toJson<DateTime>(clientTimestamp),
      'sequence': serializer.toJson<int?>(sequence),
      'attempts': serializer.toJson<int>(attempts),
      'nextRetryAt': serializer.toJson<DateTime?>(nextRetryAt),
      'lastError': serializer.toJson<String?>(lastError),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'serverAckJson': serializer.toJson<String?>(serverAckJson),
      'priority': serializer.toJson<int>(priority),
      'requiresFifo': serializer.toJson<bool>(requiresFifo),
    };
  }

  OutboundQueueItem copyWith({
    int? id,
    String? clientEventId,
    String? operationType,
    String? method,
    String? endpoint,
    String? payloadJson,
    String? status,
    DateTime? createdAt,
    DateTime? clientTimestamp,
    Value<int?> sequence = const Value.absent(),
    int? attempts,
    Value<DateTime?> nextRetryAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    Value<DateTime?> syncedAt = const Value.absent(),
    Value<String?> serverAckJson = const Value.absent(),
    int? priority,
    bool? requiresFifo,
  }) => OutboundQueueItem(
    id: id ?? this.id,
    clientEventId: clientEventId ?? this.clientEventId,
    operationType: operationType ?? this.operationType,
    method: method ?? this.method,
    endpoint: endpoint ?? this.endpoint,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    clientTimestamp: clientTimestamp ?? this.clientTimestamp,
    sequence: sequence.present ? sequence.value : this.sequence,
    attempts: attempts ?? this.attempts,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    serverAckJson:
        serverAckJson.present ? serverAckJson.value : this.serverAckJson,
    priority: priority ?? this.priority,
    requiresFifo: requiresFifo ?? this.requiresFifo,
  );
  OutboundQueueItem copyWithCompanion(OutboundQueueItemsCompanion data) {
    return OutboundQueueItem(
      id: data.id.present ? data.id.value : this.id,
      clientEventId:
          data.clientEventId.present
              ? data.clientEventId.value
              : this.clientEventId,
      operationType:
          data.operationType.present
              ? data.operationType.value
              : this.operationType,
      method: data.method.present ? data.method.value : this.method,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      clientTimestamp:
          data.clientTimestamp.present
              ? data.clientTimestamp.value
              : this.clientTimestamp,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextRetryAt:
          data.nextRetryAt.present ? data.nextRetryAt.value : this.nextRetryAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      serverAckJson:
          data.serverAckJson.present
              ? data.serverAckJson.value
              : this.serverAckJson,
      priority: data.priority.present ? data.priority.value : this.priority,
      requiresFifo:
          data.requiresFifo.present
              ? data.requiresFifo.value
              : this.requiresFifo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboundQueueItem(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('operationType: $operationType, ')
          ..write('method: $method, ')
          ..write('endpoint: $endpoint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('clientTimestamp: $clientTimestamp, ')
          ..write('sequence: $sequence, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('serverAckJson: $serverAckJson, ')
          ..write('priority: $priority, ')
          ..write('requiresFifo: $requiresFifo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientEventId,
    operationType,
    method,
    endpoint,
    payloadJson,
    status,
    createdAt,
    clientTimestamp,
    sequence,
    attempts,
    nextRetryAt,
    lastError,
    syncedAt,
    serverAckJson,
    priority,
    requiresFifo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboundQueueItem &&
          other.id == this.id &&
          other.clientEventId == this.clientEventId &&
          other.operationType == this.operationType &&
          other.method == this.method &&
          other.endpoint == this.endpoint &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.clientTimestamp == this.clientTimestamp &&
          other.sequence == this.sequence &&
          other.attempts == this.attempts &&
          other.nextRetryAt == this.nextRetryAt &&
          other.lastError == this.lastError &&
          other.syncedAt == this.syncedAt &&
          other.serverAckJson == this.serverAckJson &&
          other.priority == this.priority &&
          other.requiresFifo == this.requiresFifo);
}

class OutboundQueueItemsCompanion extends UpdateCompanion<OutboundQueueItem> {
  final Value<int> id;
  final Value<String> clientEventId;
  final Value<String> operationType;
  final Value<String> method;
  final Value<String> endpoint;
  final Value<String> payloadJson;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> clientTimestamp;
  final Value<int?> sequence;
  final Value<int> attempts;
  final Value<DateTime?> nextRetryAt;
  final Value<String?> lastError;
  final Value<DateTime?> syncedAt;
  final Value<String?> serverAckJson;
  final Value<int> priority;
  final Value<bool> requiresFifo;
  const OutboundQueueItemsCompanion({
    this.id = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.method = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.clientTimestamp = const Value.absent(),
    this.sequence = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.serverAckJson = const Value.absent(),
    this.priority = const Value.absent(),
    this.requiresFifo = const Value.absent(),
  });
  OutboundQueueItemsCompanion.insert({
    this.id = const Value.absent(),
    required String clientEventId,
    required String operationType,
    required String method,
    required String endpoint,
    required String payloadJson,
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime clientTimestamp,
    this.sequence = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.serverAckJson = const Value.absent(),
    this.priority = const Value.absent(),
    this.requiresFifo = const Value.absent(),
  }) : clientEventId = Value(clientEventId),
       operationType = Value(operationType),
       method = Value(method),
       endpoint = Value(endpoint),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt),
       clientTimestamp = Value(clientTimestamp);
  static Insertable<OutboundQueueItem> custom({
    Expression<int>? id,
    Expression<String>? clientEventId,
    Expression<String>? operationType,
    Expression<String>? method,
    Expression<String>? endpoint,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? clientTimestamp,
    Expression<int>? sequence,
    Expression<int>? attempts,
    Expression<DateTime>? nextRetryAt,
    Expression<String>? lastError,
    Expression<DateTime>? syncedAt,
    Expression<String>? serverAckJson,
    Expression<int>? priority,
    Expression<bool>? requiresFifo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (operationType != null) 'operation_type': operationType,
      if (method != null) 'method': method,
      if (endpoint != null) 'endpoint': endpoint,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (clientTimestamp != null) 'client_timestamp': clientTimestamp,
      if (sequence != null) 'sequence': sequence,
      if (attempts != null) 'attempts': attempts,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (lastError != null) 'last_error': lastError,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (serverAckJson != null) 'server_ack_json': serverAckJson,
      if (priority != null) 'priority': priority,
      if (requiresFifo != null) 'requires_fifo': requiresFifo,
    });
  }

  OutboundQueueItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientEventId,
    Value<String>? operationType,
    Value<String>? method,
    Value<String>? endpoint,
    Value<String>? payloadJson,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? clientTimestamp,
    Value<int?>? sequence,
    Value<int>? attempts,
    Value<DateTime?>? nextRetryAt,
    Value<String?>? lastError,
    Value<DateTime?>? syncedAt,
    Value<String?>? serverAckJson,
    Value<int>? priority,
    Value<bool>? requiresFifo,
  }) {
    return OutboundQueueItemsCompanion(
      id: id ?? this.id,
      clientEventId: clientEventId ?? this.clientEventId,
      operationType: operationType ?? this.operationType,
      method: method ?? this.method,
      endpoint: endpoint ?? this.endpoint,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      clientTimestamp: clientTimestamp ?? this.clientTimestamp,
      sequence: sequence ?? this.sequence,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      syncedAt: syncedAt ?? this.syncedAt,
      serverAckJson: serverAckJson ?? this.serverAckJson,
      priority: priority ?? this.priority,
      requiresFifo: requiresFifo ?? this.requiresFifo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (clientTimestamp.present) {
      map['client_timestamp'] = Variable<DateTime>(clientTimestamp.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<DateTime>(nextRetryAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (serverAckJson.present) {
      map['server_ack_json'] = Variable<String>(serverAckJson.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (requiresFifo.present) {
      map['requires_fifo'] = Variable<bool>(requiresFifo.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboundQueueItemsCompanion(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('operationType: $operationType, ')
          ..write('method: $method, ')
          ..write('endpoint: $endpoint, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('clientTimestamp: $clientTimestamp, ')
          ..write('sequence: $sequence, ')
          ..write('attempts: $attempts, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('lastError: $lastError, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('serverAckJson: $serverAckJson, ')
          ..write('priority: $priority, ')
          ..write('requiresFifo: $requiresFifo')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const SyncMetadataData({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncMetadataData copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => SyncMetadataData(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OutboundQueueItemsTable outboundQueueItems =
      $OutboundQueueItemsTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    outboundQueueItems,
    syncMetadata,
  ];
}

typedef $$OutboundQueueItemsTableCreateCompanionBuilder =
    OutboundQueueItemsCompanion Function({
      Value<int> id,
      required String clientEventId,
      required String operationType,
      required String method,
      required String endpoint,
      required String payloadJson,
      Value<String> status,
      required DateTime createdAt,
      required DateTime clientTimestamp,
      Value<int?> sequence,
      Value<int> attempts,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastError,
      Value<DateTime?> syncedAt,
      Value<String?> serverAckJson,
      Value<int> priority,
      Value<bool> requiresFifo,
    });
typedef $$OutboundQueueItemsTableUpdateCompanionBuilder =
    OutboundQueueItemsCompanion Function({
      Value<int> id,
      Value<String> clientEventId,
      Value<String> operationType,
      Value<String> method,
      Value<String> endpoint,
      Value<String> payloadJson,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> clientTimestamp,
      Value<int?> sequence,
      Value<int> attempts,
      Value<DateTime?> nextRetryAt,
      Value<String?> lastError,
      Value<DateTime?> syncedAt,
      Value<String?> serverAckJson,
      Value<int> priority,
      Value<bool> requiresFifo,
    });

class $$OutboundQueueItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboundQueueItemsTable,
          OutboundQueueItem,
          $$OutboundQueueItemsTableFilterComposer,
          $$OutboundQueueItemsTableOrderingComposer,
          $$OutboundQueueItemsTableCreateCompanionBuilder,
          $$OutboundQueueItemsTableUpdateCompanionBuilder
        > {
  $$OutboundQueueItemsTableTableManager(
    _$AppDatabase db,
    $OutboundQueueItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$OutboundQueueItemsTableFilterComposer(
            ComposerState(db, table),
          ),
          orderingComposer: $$OutboundQueueItemsTableOrderingComposer(
            ComposerState(db, table),
          ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientEventId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> endpoint = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> clientTimestamp = const Value.absent(),
                Value<int?> sequence = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> serverAckJson = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> requiresFifo = const Value.absent(),
              }) => OutboundQueueItemsCompanion(
                id: id,
                clientEventId: clientEventId,
                operationType: operationType,
                method: method,
                endpoint: endpoint,
                payloadJson: payloadJson,
                status: status,
                createdAt: createdAt,
                clientTimestamp: clientTimestamp,
                sequence: sequence,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                syncedAt: syncedAt,
                serverAckJson: serverAckJson,
                priority: priority,
                requiresFifo: requiresFifo,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientEventId,
                required String operationType,
                required String method,
                required String endpoint,
                required String payloadJson,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime clientTimestamp,
                Value<int?> sequence = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextRetryAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<String?> serverAckJson = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> requiresFifo = const Value.absent(),
              }) => OutboundQueueItemsCompanion.insert(
                id: id,
                clientEventId: clientEventId,
                operationType: operationType,
                method: method,
                endpoint: endpoint,
                payloadJson: payloadJson,
                status: status,
                createdAt: createdAt,
                clientTimestamp: clientTimestamp,
                sequence: sequence,
                attempts: attempts,
                nextRetryAt: nextRetryAt,
                lastError: lastError,
                syncedAt: syncedAt,
                serverAckJson: serverAckJson,
                priority: priority,
                requiresFifo: requiresFifo,
              ),
        ),
      );
}

class $$OutboundQueueItemsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $OutboundQueueItemsTable> {
  $$OutboundQueueItemsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
    column: $state.table.id,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get clientEventId => $state.composableBuilder(
    column: $state.table.clientEventId,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get operationType => $state.composableBuilder(
    column: $state.table.operationType,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get method => $state.composableBuilder(
    column: $state.table.method,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get endpoint => $state.composableBuilder(
    column: $state.table.endpoint,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get payloadJson => $state.composableBuilder(
    column: $state.table.payloadJson,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get status => $state.composableBuilder(
    column: $state.table.status,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
    column: $state.table.createdAt,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get clientTimestamp => $state.composableBuilder(
    column: $state.table.clientTimestamp,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<int> get sequence => $state.composableBuilder(
    column: $state.table.sequence,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<int> get attempts => $state.composableBuilder(
    column: $state.table.attempts,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get nextRetryAt => $state.composableBuilder(
    column: $state.table.nextRetryAt,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get lastError => $state.composableBuilder(
    column: $state.table.lastError,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get syncedAt => $state.composableBuilder(
    column: $state.table.syncedAt,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get serverAckJson => $state.composableBuilder(
    column: $state.table.serverAckJson,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<int> get priority => $state.composableBuilder(
    column: $state.table.priority,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<bool> get requiresFifo => $state.composableBuilder(
    column: $state.table.requiresFifo,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );
}

class $$OutboundQueueItemsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $OutboundQueueItemsTable> {
  $$OutboundQueueItemsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
    column: $state.table.id,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get clientEventId => $state.composableBuilder(
    column: $state.table.clientEventId,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get operationType => $state.composableBuilder(
    column: $state.table.operationType,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get method => $state.composableBuilder(
    column: $state.table.method,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get endpoint => $state.composableBuilder(
    column: $state.table.endpoint,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get payloadJson => $state.composableBuilder(
    column: $state.table.payloadJson,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get status => $state.composableBuilder(
    column: $state.table.status,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
    column: $state.table.createdAt,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get clientTimestamp => $state.composableBuilder(
    column: $state.table.clientTimestamp,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<int> get sequence => $state.composableBuilder(
    column: $state.table.sequence,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<int> get attempts => $state.composableBuilder(
    column: $state.table.attempts,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get nextRetryAt => $state.composableBuilder(
    column: $state.table.nextRetryAt,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get lastError => $state.composableBuilder(
    column: $state.table.lastError,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get syncedAt => $state.composableBuilder(
    column: $state.table.syncedAt,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get serverAckJson => $state.composableBuilder(
    column: $state.table.serverAckJson,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<int> get priority => $state.composableBuilder(
    column: $state.table.priority,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<bool> get requiresFifo => $state.composableBuilder(
    column: $state.table.requiresFifo,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );
}

typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$SyncMetadataTableFilterComposer(
            ComposerState(db, table),
          ),
          orderingComposer: $$SyncMetadataTableOrderingComposer(
            ComposerState(db, table),
          ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
        ),
      );
}

class $$SyncMetadataTableFilterComposer
    extends FilterComposer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer(super.$state);
  ColumnFilters<String> get key => $state.composableBuilder(
    column: $state.table.key,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<String> get value => $state.composableBuilder(
    column: $state.table.value,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );

  ColumnFilters<DateTime> get updatedAt => $state.composableBuilder(
    column: $state.table.updatedAt,
    builder:
        (column, joinBuilders) =>
            ColumnFilters(column, joinBuilders: joinBuilders),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer(super.$state);
  ColumnOrderings<String> get key => $state.composableBuilder(
    column: $state.table.key,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<String> get value => $state.composableBuilder(
    column: $state.table.value,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );

  ColumnOrderings<DateTime> get updatedAt => $state.composableBuilder(
    column: $state.table.updatedAt,
    builder:
        (column, joinBuilders) =>
            ColumnOrderings(column, joinBuilders: joinBuilders),
  );
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OutboundQueueItemsTableTableManager get outboundQueueItems =>
      $$OutboundQueueItemsTableTableManager(_db, _db.outboundQueueItems);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
