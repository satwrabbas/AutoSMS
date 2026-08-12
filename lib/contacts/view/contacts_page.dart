import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:auto_sms/l10n/l10n.dart';
import '../cubit/contacts_cubit.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ContactsCubit(repository: context.read<CrmRepository>())..loadContacts(),
      child: const ContactsView(),
    );
  }
}

class ContactsView extends StatefulWidget {
  const ContactsView({super.key});

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  String? _selectedFilterGroupId; 
  final Set<Contact> _selectedContacts = {}; 
  bool get _isMultiSelectMode => _selectedContacts.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getLocalizedContactError(BuildContext context, String rawError) {
    final l10n = context.l10n;
    if (rawError.startsWith('errAddContact:')) {
      return l10n.errAddContact(rawError.substring('errAddContact:'.length));
    }
    if (rawError.startsWith('errAssignGroup:')) {
      return l10n.errAssignGroup(rawError.substring('errAssignGroup:'.length));
    }
    if (rawError.startsWith('errAssignGroupMultiple:')) {
      return l10n.errAssignGroupMultiple(rawError.substring('errAssignGroupMultiple:'.length));
    }
    if (rawError.startsWith('errDeleteContact:')) {
      return l10n.errDeleteContact(rawError.substring('errDeleteContact:'.length));
    }
    if (rawError.startsWith('errEditContact:')) {
      return l10n.errEditContact(rawError.substring('errEditContact:'.length));
    }
    if (rawError.startsWith('errSyncContacts:')) {
      return l10n.errSyncContacts(rawError.substring('errSyncContacts:'.length));
    }
    if (rawError == 'errPermissionContacts') {
      return l10n.errPermissionContacts;
    }
    return rawError;
  }

  void _showAssignGroupDialog(BuildContext context, List<Group> groups, {Contact? singleContact}) {
    final l10n = context.l10n;
    final cubit = context.read<ContactsCubit>();
    final isBulk = singleContact == null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isBulk 
              ? l10n.assignGroupBulkTitle(_selectedContacts.length) 
              : l10n.assignGroupSingleTitle(singleContact.name),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_off),
                title: Text(l10n.noGroup),
                onTap: () {
                  isBulk ? cubit.assignGroupToMultiple(_selectedContacts.toList(), null) : cubit.assignGroup(singleContact!, null);
                  if (isBulk) setState(() => _selectedContacts.clear()); 
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...groups.map((g) => ListTile(
                leading: const Icon(Icons.group, color: Colors.blue),
                title: Text(g.name),
                onTap: () {
                  isBulk ? cubit.assignGroupToMultiple(_selectedContacts.toList(), g.id) : cubit.assignGroup(singleContact!, g.id);
                  if (isBulk) setState(() => _selectedContacts.clear());
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddOrEditContactDialog(BuildContext context, List<Group> groups, {Contact? contact}) {
    final l10n = context.l10n;
    final isEditing = contact != null;
    final nameController = TextEditingController(text: isEditing ? contact.name : '');
    final phoneController = TextEditingController(text: isEditing ? contact.phone : '');
    String? newContactGroupId;
    final cubit = context.read<ContactsCubit>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEditing ? l10n.editContactTitle : l10n.addContactTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: l10n.nameLabel)),
                const SizedBox(height: 8),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.phoneLabel)),
                const SizedBox(height: 16),
                if (!isEditing && groups.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    value: newContactGroupId,
                    decoration: InputDecoration(labelText: l10n.assignGroupOptional),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.noGroup)),
                      ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                    ],
                    onChanged: (val) => setStateDialog(() => newContactGroupId = val),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                  if (isEditing) {
                    cubit.editContact(contact, nameController.text.trim(), phoneController.text.trim());
                  } else {
                    cubit.addManualContact(nameController.text.trim(), phoneController.text.trim(), newContactGroupId);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(isEditing ? l10n.saveChanges : l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  void _showContactOptions(BuildContext context, Contact contact, List<Group> groups) {
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(contact.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(contact.phone, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(Icons.call, l10n.actionCall, Colors.blue, () async {
                  final url = Uri.parse('tel:${contact.phone}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    if (context.mounted) _showSnackBar(context, l10n.cannotOpenCall, Colors.red);
                  }
                }),
                _buildActionButton(Icons.chat, l10n.actionWhatsapp, Colors.green, () async {
                  String cleanPhone = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
                  if (cleanPhone.startsWith('00')) {
                    cleanPhone = cleanPhone.replaceFirst('00', '');
                  } else if (cleanPhone.startsWith('+')) {
                    cleanPhone = cleanPhone.replaceFirst('+', '');
                  }
                  final url = Uri.parse('https://wa.me/$cleanPhone');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) _showSnackBar(context, l10n.cannotOpenWhatsapp, Colors.red);
                  }
                }),
                _buildActionButton(Icons.message, l10n.actionSms, Colors.orange, () async {
                  final url = Uri.parse('sms:${contact.phone}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    if (context.mounted) _showSnackBar(context, l10n.cannotOpenSms, Colors.red);
                  }
                }),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.label, color: Colors.blue),
              title: Text(l10n.assignGroup),
              onTap: () { Navigator.pop(context); _showAssignGroupDialog(context, groups, singleContact: contact); },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.teal),
              title: Text(l10n.editDetails),
              onTap: () { Navigator.pop(context); _showAddOrEditContactDialog(context, groups, contact: contact); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.deleteContact, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                context.read<ContactsCubit>().deleteContact(contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<ContactsCubit, ContactsState>(
      builder: (context, state) {
        final appBar = _isMultiSelectMode
            ? AppBar(
                backgroundColor: Colors.teal,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white), 
                  onPressed: () => setState(() => _selectedContacts.clear()),
                ),
                title: Text(l10n.selectedCount(_selectedContacts.length), style: const TextStyle(color: Colors.white)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.group_add, color: Colors.white),
                    tooltip: l10n.assignGroupTooltip,
                    onPressed: () {
                      if (state is ContactsLoaded) {
                        _showAssignGroupDialog(context, state.groups);
                      }
                    },
                  ),
                ],
              )
            : AppBar(
                title: Text(l10n.contactsTitle),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sync_outlined), 
                    tooltip: l10n.syncContactsTooltip, 
                    onPressed: () => context.read<ContactsCubit>().syncFromPhone(),
                  ),
                ],
              );
        return Scaffold(
          appBar: appBar,
          body: _buildBody(context, state),
          floatingActionButton: !_isMultiSelectMode && state is ContactsLoaded
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddOrEditContactDialog(context, state.groups),
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.addContact),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ContactsState state) {
    final l10n = context.l10n;

    if (state is ContactsLoading) return const Center(child: CircularProgressIndicator());
    if (state is ContactsSyncing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            const CircularProgressIndicator(color: Colors.green), 
            const SizedBox(height: 16), 
            Text(l10n.syncingContacts),
          ],
        ),
      );
    }
    if (state is ContactsError) {
      return Center(
        child: Text(
          _getLocalizedContactError(context, state.message), 
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (state is ContactsLoaded) {
      final contacts = state.contacts;
      final groups = state.groups;
      final filteredContacts = contacts.where((c) {
        final matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.phone.contains(_searchQuery);
        bool matchesGroup = true;
        if (_selectedFilterGroupId == 'none') {
          matchesGroup = c.groupId == null; 
        } else if (_selectedFilterGroupId != null) {
          matchesGroup = c.groupId == _selectedFilterGroupId;
        }
        return matchesSearch && matchesGroup;
      }).toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholder, 
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                      ) 
                    : null,
                filled: true, 
                fillColor: Colors.grey[200], 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ChoiceChip(
                  label: Text(l10n.filterAll), 
                  selected: _selectedFilterGroupId == null,
                  onSelected: (val) => setState(() => _selectedFilterGroupId = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(l10n.noGroup, style: const TextStyle(color: Colors.deepOrange)), 
                  selected: _selectedFilterGroupId == 'none',
                  onSelected: (val) => setState(() => _selectedFilterGroupId = val ? 'none' : null),
                ),
                const SizedBox(width: 8),
                ...groups.map((g) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(g.name, style: TextStyle(color: _selectedFilterGroupId == g.id ? Colors.white : Colors.black)),
                    selectedColor: Colors.blue,
                    selected: _selectedFilterGroupId == g.id,
                    onSelected: (val) => setState(() => _selectedFilterGroupId = val ? g.id : null),
                  ),
                )),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: filteredContacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(l10n.noContactsHere, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddOrEditContactDialog(context, groups), 
                          icon: const Icon(Icons.add), 
                          label: Text(l10n.addContactTitle),
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final isSelected = _selectedContacts.contains(contact);
                      String groupName = l10n.noGroup;
                      Color groupColor = Colors.grey;
                      if (contact.groupId != null) {
                        try {
                          groupName = groups.firstWhere((g) => g.id == contact.groupId).name;
                          groupColor = Colors.blue;
                        } catch (_) {} 
                      }
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Colors.teal.withOpacity(0.1),
                        leading: _isMultiSelectMode
                            ? Checkbox(
                                value: isSelected,
                                activeColor: Colors.teal,
                                onChanged: (_) => setState(() => isSelected ? _selectedContacts.remove(contact) : _selectedContacts.add(contact)),
                              )
                            : const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(contact.phone),
                        trailing: Chip(label: Text(groupName, style: const TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: groupColor),
                        onLongPress: () => setState(() => _selectedContacts.add(contact)),
                        onTap: () {
                          if (_isMultiSelectMode) {
                            setState(() => isSelected ? _selectedContacts.remove(contact) : _selectedContacts.add(contact));
                          } else {
                            _showContactOptions(context, contact, groups);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}