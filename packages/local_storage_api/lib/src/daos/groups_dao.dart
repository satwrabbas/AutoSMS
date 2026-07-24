// packages/local_storage_api/lib/src/daos/groups_dao.dart

import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'groups_dao.g.dart';

@DriftAccessor(tables: [Groups])
class GroupsDao extends DatabaseAccessor<AppDatabase> with _$GroupsDaoMixin {
  GroupsDao(AppDatabase db) : super(db);

  Future<List<Group>> getAllActiveGroups() {
    return (select(groups)..where((t) => t.isDeleted.equals(false))).get();
  }

  Future<int> insertGroup(GroupsCompanion group) {
    return into(groups).insert(
      group.copyWith(syncStatus: const Value(1)),
    );
  }

  Future<bool> updateGroup(Group group) {
    return update(groups).replace(
      group.copyWith(
        syncStatus: 2,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<int> softDeleteGroup(String groupId) {
    return (update(groups)..where((t) => t.id.equals(groupId))).write(
      GroupsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(3),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}