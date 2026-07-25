part of 'contacts_cubit.dart';

abstract class ContactsState {}

class ContactsInitial extends ContactsState {}

class ContactsLoading extends ContactsState {} 

class ContactsSyncing extends ContactsState {} 

class ContactsLoaded extends ContactsState { // 🌟 أضفنا قائمة المجموعات هنا
  
  ContactsLoaded({required this.contacts, required this.groups});
  final List<Contact> contacts;
  final List<Group> groups;
}

class ContactsError extends ContactsState {
  ContactsError({required this.message});
  final String message;
}