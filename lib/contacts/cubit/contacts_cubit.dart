import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as phone_contacts;

part 'contacts_state.dart';

class ContactsCubit extends Cubit<ContactsState> {
  ContactsCubit({required CrmRepository repository})
      : _repository = repository,
        super(ContactsInitial());

  final CrmRepository _repository;

  Future<void> loadContacts() async {
    emit(ContactsLoading());
    try {
      final contacts = await _repository.getContacts();
      final groups = await _repository.getGroups();
      emit(ContactsLoaded(contacts: contacts, groups: groups));
    } catch (e) {
      emit(ContactsError(message: e.toString()));
    }
  }

  Future<void> addManualContact(String name, String phone, String? groupId) async {
    try {
      await _repository.saveSyncedContacts([{'name': name, 'phone': phone}]);
      
      if (groupId != null) {
        final allContacts = await _repository.getContacts();
        final newContact = allContacts.firstWhere(
          (c) => c.phone.replaceAll(RegExp(r'\s+|-'), '') == phone.replaceAll(RegExp(r'\s+|-'), ''),
          orElse: () => const Contact(id: '', name: '', phone: '', groupId: null, isDeleted: false),
        );
        if (newContact.id.isNotEmpty) {
          await _repository.updateContactGroup(newContact, groupId);
        }
      }

      await loadContacts();
      _repository.syncAllToCloud();
    } catch (e) {
      emit(ContactsError(message: 'خطأ في إضافة العميل: $e'));
    }
  }

  Future<void> assignGroup(Contact contact, String? groupId) async {
    try {
      await _repository.updateContactGroup(contact, groupId);
      await loadContacts(); 
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(ContactsError(message: 'خطأ في تعيين المجموعة: $e'));
    }
  }

  Future<void> assignGroupToMultiple(List<Contact> contacts, String? groupId) async {
    try {
      for (var contact in contacts) {
        await _repository.updateContactGroup(contact, groupId);
      }
      await loadContacts(); 
      _repository.syncAllToCloud(); 
    } catch (e) {
      emit(ContactsError(message: 'خطأ في التعيين المتعدد: $e'));
    }
  }

  Future<void> deleteContact(Contact contact) async {
    try {
      await _repository.deleteContact(contact);
      await loadContacts();
      _repository.syncAllToCloud();
    } catch (e) {
      emit(ContactsError(message: 'خطأ في الحذف: $e'));
    }
  }

  Future<void> editContact(Contact contact, String newName, String newPhone) async {
    try {
      await _repository.updateContactInfo(contact, newName, newPhone);
      await loadContacts();
      _repository.syncAllToCloud();
    } catch (e) {
      emit(ContactsError(message: 'خطأ في التعديل: $e'));
    }
  }

  Future<void> syncFromPhone() async {
    emit(ContactsSyncing());
    try {
      final status = await phone_contacts.FlutterContacts.permissions.request(
        phone_contacts.PermissionType.read,
      );

      if (status == phone_contacts.PermissionStatus.granted || status == phone_contacts.PermissionStatus.limited) {
        final contactsFromPhone = await phone_contacts.FlutterContacts.getAll(
          properties: {phone_contacts.ContactProperty.name, phone_contacts.ContactProperty.phone},
        );

        final List<Map<String, String>> formattedContacts =[];
        for (var c in contactsFromPhone) {
          if (c.phones.isNotEmpty) {
            formattedContacts.add({
              'name': c.displayName ?? 'بدون اسم',
              'phone': c.phones.first.number,
            });
          }
        }

        await _repository.saveSyncedContacts(formattedContacts);
        await loadContacts();
        _repository.syncAllToCloud();
      } else {
        emit(ContactsError(message: 'تم رفض صلاحية الوصول لجهات الاتصال'));
      }
    } catch (e) {
      emit(ContactsError(message: 'حدث خطأ أثناء المزامنة: $e'));
    }
  }
}