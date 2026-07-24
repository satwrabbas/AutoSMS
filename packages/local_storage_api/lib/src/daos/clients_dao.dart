// packages/local_storage_api/lib/src/daos/clients_dao.dart

import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'clients_dao.g.dart';

@DriftAccessor(tables: [Clients])
class ClientsDao extends DatabaseAccessor<AppDatabase> with _$ClientsDaoMixin {
  ClientsDao(AppDatabase db) : super(db);

  Future<List<Client>> getClientsByGroup(String groupId) {
    return (select(clients)
          ..where((t) => t.groupId.equals(groupId) & t.isDeleted.equals(false)))
        .get();
  }

  Future<int> insertClient(ClientsCompanion client) {
    return into(clients).insert(
      client.copyWith(syncStatus: const Value(1)),
    );
  }

  Future<int> softDeleteClient(String clientId) {
    return (update(clients)..where((t) => t.id.equals(clientId))).write(
      ClientsCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value(3),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}