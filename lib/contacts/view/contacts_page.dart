import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:local_storage_api/local_storage_api.dart';
import 'package:url_launcher/url_launcher.dart'; 
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
  // 🌟 تم التعديل إلى String? بدلاً من int?
  String? _selectedFilterGroupId; 
  final Set<Contact> _selectedContacts = {}; 

  bool get _isMultiSelectMode => _selectedContacts.isNotEmpty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAssignGroupDialog(BuildContext context, List<Group> groups, {Contact? singleContact}) {
    final cubit = context.read<ContactsCubit>();
    final isBulk = singleContact == null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBulk ? 'تعيين مجموعة لـ ${_selectedContacts.length} عملاء' : 'تعيين مجموعة لـ ${singleContact.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children:[
              ListTile(
                leading: const Icon(Icons.person_off),
                title: const Text('بدون مجموعة'),
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
    final isEditing = contact != null;
    final nameController = TextEditingController(text: isEditing ? contact.name : '');
    final phoneController = TextEditingController(text: isEditing ? contact.phone : '');
    
    String? newContactGroupId;

    final cubit = context.read<ContactsCubit>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(isEditing ? 'تعديل بيانات العميل ✏️' : 'إضافة عميل جديد 👤'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
                const SizedBox(height: 8),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                const SizedBox(height: 16),
                
                if (!isEditing && groups.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    value: newContactGroupId,
                    decoration: const InputDecoration(labelText: 'تعيين لمجموعة (اختياري)'),
                    items:[
                      const DropdownMenuItem(value: null, child: Text('بدون مجموعة')),
                      ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                    ],
                    onChanged: (val) => setStateDialog(() => newContactGroupId = val),
                  ),
              ],
            ),
          ),
          actions:[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
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
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // 3. القائمة السفلية (BottomSheet) للإجراءات السريعة
  void _showContactOptions(BuildContext context, Contact contact, List<Group> groups) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:[
            const SizedBox(height: 16),
            Text(contact.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(contact.phone, style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            
            // 🌟 أزرار الاتصال السريع المحسنة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:[
                _buildActionButton(Icons.call, 'اتصال', Colors.blue, () async {
                  final url = Uri.parse('tel:${contact.phone}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    if (context.mounted) _showSnackBar(context, 'لا يمكن فتح تطبيق الاتصال', Colors.red);
                  }
                }),
                _buildActionButton(Icons.chat, 'واتساب', Colors.green, () async {
                  // 1. تنظيف الرقم (إبقاء الأرقام وعلامة + فقط إن وجدت)
                  String cleanPhone = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
                  
                  // 2. محاولة تنسيق الرقم ليتوافق مع متطلبات واتساب (رمز الدولة ضروري)
                  // ملاحظة: يُفضل أن يقوم المستخدم بحفظ الأرقام بالصيغة الدولية (مثل +963 أو +966)
                  // إذا كان الرقم يبدأ بصفر محلي، نقوم بإزالته (مثال لبعض الدول، قد تحتاج لتخصيصه حسب بلدك)
                  if (cleanPhone.startsWith('00')) {
                    cleanPhone = cleanPhone.replaceFirst('00', '');
                  } else if (cleanPhone.startsWith('+')) {
                    cleanPhone = cleanPhone.replaceFirst('+', '');
                  }
                  
                  // رابط الواتساب العالمي
                  final url = Uri.parse('https://wa.me/$cleanPhone');
                  
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) _showSnackBar(context, 'تطبيق الواتساب غير مثبت أو الرقم غير صالح', Colors.red);
                  }
                }),
                _buildActionButton(Icons.message, 'رسالة SMS', Colors.orange, () async {
                  final url = Uri.parse('sms:${contact.phone}');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    if (context.mounted) _showSnackBar(context, 'لا يمكن فتح تطبيق الرسائل', Colors.red);
                  }
                }),
              ],
            ),
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.label, color: Colors.blue),
              title: const Text('تعيين مجموعة'),
              onTap: () { Navigator.pop(context); _showAssignGroupDialog(context, groups, singleContact: contact); },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.teal),
              title: const Text('تعديل البيانات'),
              onTap: () { Navigator.pop(context); _showAddOrEditContactDialog(context, groups, contact: contact); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف العميل', style: TextStyle(color: Colors.red)),
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
          children:[
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
    return BlocBuilder<ContactsCubit, ContactsState>(
      builder: (context, state) {
        final appBar = _isMultiSelectMode
            ? AppBar(
                backgroundColor: Colors.teal,
                leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _selectedContacts.clear())),
                title: Text('${_selectedContacts.length} محدد', style: const TextStyle(color: Colors.white)),
                actions:[
                  IconButton(
                    icon: const Icon(Icons.group_add, color: Colors.white),
                    tooltip: 'تعيين مجموعة للمحددين',
                    onPressed: () {
                      if (state is ContactsLoaded) {
                        _showAssignGroupDialog(context, state.groups);
                      }
                    },
                  ),
                ],
              )
            : AppBar(
                title: const Text('العملاء (CRM)'),
                actions:[
                  IconButton(icon: const Icon(Icons.sync_outlined), tooltip: 'مزامنة الأسماء من الهاتف', onPressed: () => context.read<ContactsCubit>().syncFromPhone()),
                ],
              );

        return Scaffold(
          appBar: appBar,
          body: _buildBody(context, state),
          floatingActionButton: !_isMultiSelectMode && state is ContactsLoaded
              ? FloatingActionButton.extended(
                  onPressed: () => _showAddOrEditContactDialog(context, state.groups),
                  icon: const Icon(Icons.person_add),
                  label: const Text('إضافة عميل'),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ContactsState state) {
    if (state is ContactsLoading) return const Center(child: CircularProgressIndicator());
    if (state is ContactsSyncing) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[CircularProgressIndicator(color: Colors.green), SizedBox(height: 16), Text('جاري سحب الأسماء...')]));
    }
    if (state is ContactsError) return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
    if (state is ContactsLoaded) {
      final contacts = state.contacts;
      final groups = state.groups;

      final filteredContacts = contacts.where((c) {
        final matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) || c.phone.contains(_searchQuery);
        bool matchesGroup = true;
        // 🌟 التعديل هنا ليتوافق مع النصوص
        if (_selectedFilterGroupId == 'none') {
          matchesGroup = c.groupId == null; 
        } else if (_selectedFilterGroupId != null) {
          matchesGroup = c.groupId == _selectedFilterGroupId;
        }
        return matchesSearch && matchesGroup;
      }).toList();

      return Column(
        children:[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الهاتف...', prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                filled: true, fillColor: Colors.grey[200], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children:[
                ChoiceChip(
                  label: const Text('الكل'), selected: _selectedFilterGroupId == null,
                  onSelected: (val) => setState(() => _selectedFilterGroupId = null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('بدون مجموعة', style: TextStyle(color: Colors.deepOrange)), selected: _selectedFilterGroupId == 'none',
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
                      children:[
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('لا يوجد عملاء هنا', style: TextStyle(fontSize: 18, color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddOrEditContactDialog(context, groups), 
                          icon: const Icon(Icons.add), 
                          label: const Text('إضافة عميل جديد')
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = filteredContacts[index];
                      final isSelected = _selectedContacts.contains(contact);
                      
                      String groupName = 'بدون مجموعة';
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