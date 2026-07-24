import 'package:drift/drift.dart';

// --- جدول المجموعات ---
class Groups extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  
  // حقول خاصة بالمعمارية (Sync & Soft Delete)
  IntColumn get syncStatus => integer().withDefault(const Constant(0))(); // 0: Synced, 1: PendingInsert, 2: PendingUpdate, 3: PendingDelete
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- جدول العملاء ---
class Clients extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phoneNumber => text().withLength(min: 5, max: 20)();
  TextColumn get groupId => text().nullable().references(Groups, #id)(); // مفتاح أجنبي
  
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- جدول الحملات المجدولة ---
class Campaigns extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get title => text().withLength(min: 1, max: 100)();
  TextColumn get messageTemplate => text()();
  TextColumn get targetGroupId => text().references(Groups, #id)(); // المجموعة المستهدفة
  DateTimeColumn get scheduledDate => dateTime()(); // موعد الإرسال
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, active, completed, paused
  
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- جدول سجل الرسائل (التتبع) ---
class MessageLogs extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get campaignId => text().references(Campaigns, #id)();
  TextColumn get clientId => text().references(Clients, #id)();
  
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, sent, failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get failureReason => text().nullable()();
  DateTimeColumn get sentAt => dateTime().nullable()();
  
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}