import 'dart:convert'; // 🌟 مكتبة ה- JSON
import 'package:local_storage_api/local_storage_api.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; 
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // 🌟 مكتبة توليد المعرفات الفريدة (UUID)

class CrmRepository {
  const CrmRepository({
    required AppDatabase localStorage,
    required CloudStorageClient cloudStorage,
  })  : _localStorage = localStorage,
        _cloudStorage = cloudStorage;

  final AppDatabase _localStorage;
  final CloudStorageClient _cloudStorage;
  final _uuid = const Uuid(); // 🌟 مولد المعرفات

  // ==========================================
  // 1. قسم المصادقة والأجهزة ☁️📱
  // ==========================================
  Stream<AuthState> get authStateChanges => _cloudStorage.authStateChanges;
  Session? get currentSession => _cloudStorage.currentSession;
  // 🌟 (إضافة صغيرة لدعم أداة فحص قاعدة البيانات التي ناقشناها سابقاً)
  AppDatabase get localDatabase => _localStorage; 

  Future<void> signIn({required String email, required String password}) async {
    await _cloudStorage.signIn(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await _cloudStorage.signUp(email: email, password: password);
  }

  // ==========================================
  // 🚪 دالة تسجيل الخروج (النسخة المدمرة للذاكرة 💥)
  // ==========================================
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. نحاول مسح الجهاز من السحابة (قد يفشل إذا لم يكن هناك إنترنت)
      final deviceId = prefs.getString('registered_device_id');
      if (deviceId != null) {
        await _cloudStorage.removeDevice(deviceId);
      }
      
      // 🌟 2. السحر هنا: مسح كل الذاكرة المؤقتة (بما فيها وقت المزامنة القديم!)
      // هذا يضمن أن تسجيل الدخول القادم سيبدأ بذاكرة نظيفة 100%
      await prefs.clear(); 
      
    } catch (e) {
      print("⚠️ تعذر مسح مفتاح الجهاز من السحابة بسبب انقطاع الإنترنت: $e");
    } finally {
      // 3. مسح قاعدة البيانات المحلية (Drift)
      await _localStorage.clearAllData();
      
      // 4. تسجيل الخروج من السحابة (Supabase)
      await _cloudStorage.signOut();
    }
  }

  /// 🌟 تسجيل الجهاز في السحابة
  Future<String?> registerDevice(String deviceName, String token, String hardwareId) async {
    return await _cloudStorage.registerDevice(deviceName: deviceName, fcmToken: token, hardwareId: hardwareId);
  }

  /// 🌟 فك ارتباط الجهاز
  Future<void> removeDevice(String deviceId) async {
    await _cloudStorage.removeDevice(deviceId);
  }

  // 🌟 الدالة العبقرية الجديدة (تخزين مؤقت للأجهزة)
  Future<List<Map<String, dynamic>>> getRegisteredDevices() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // 1. نحاول جلب الأجهزة من السحابة (لو فيه إنترنت)
      final devices = await _cloudStorage.fetchDevices();
      
      // 2. نحفظها كـ JSON في ذاكرة الهاتف لكي نستخدمها لاحقاً لو انقطع الإنترنت!
      await prefs.setString('cached_devices', jsonEncode(devices));
      
      return devices;
    } catch (e) {
      // 3. ✈️ حالة انقطاع الإنترنت: نقرأ الذاكرة المحفوظة!
      final cachedString = prefs.getString('cached_devices');
      if (cachedString != null) {
        final List<dynamic> decoded = jsonDecode(cachedString);
        // تحويلها لـ List<Map> ليفهمها التطبيق
        return decoded.map((e) => e as Map<String, dynamic>).toList();
      }
      
      // 4. إذا لم يكن هناك إنترنت، ولم نفتح التطبيق سابقاً أبداً (حالة نادرة جداً)
      return[];
    }
  }

  // ==========================================
  // 2. قسم جهات الاتصال 💾
  // ==========================================

  /// 🌟 تعديل اسم ورقم العميل (مع الاحتفاظ بمجموعته ومعرفه)
  Future<void> updateContactInfo(Contact contact, String newName, String newPhone) async {
    final companion = ContactsCompanion(
      id: drift.Value(contact.id), // نحافظ على الـ ID
      name: drift.Value(newName),
      phone: drift.Value(newPhone),
      groupId: drift.Value(contact.groupId), // نحافظ على مجموعته الحالية
    );
    await _localStorage.upsertContact(companion); // نستخدم Upsert ليعمل كتحديث
  }
  
  Future<List<Contact>> getContacts() async {
    return await _localStorage.getAllContacts();
  }

  Future<void> saveSyncedContacts(List<Map<String, String>> phoneContacts) async {
    // 1. جلب جميع العملاء الموجودين حالياً
    final existingContacts = await _localStorage.getAllContacts();

    for (var contact in phoneContacts) {
      // تنظيف رقم الهاتف 
      final phone = (contact['phone'] ?? '').replaceAll(RegExp(r'\s+|-'), '');
      final name = contact['name'] ?? 'بدون اسم';

      if (phone.isEmpty) continue; 

      // 2. البحث عما إذا كان هذا الرقم موجوداً مسبقاً
      // (استخدام firstWhere مع orElse لتعمل بأمان على كل نسخ Dart)
      final existingContact = existingContacts.firstWhere(
        (c) => c.phone.replaceAll(RegExp(r'\s+|-'), '') == phone,
        orElse: () => const Contact(id: '', name: '', phone: '', groupId: null, isDeleted: false), // 🌟 أضفنا isDeleted هنا
      );

      if (existingContact.id.isNotEmpty) {
        // 💡 الرقم موجود مسبقاً! نقوم بتحديث الاسم ونحافظ على ה-ID والمجموعة
        final companion = ContactsCompanion(
          id: drift.Value(existingContact.id),
          name: drift.Value(name),
          phone: drift.Value(phone),
          groupId: drift.Value(existingContact.groupId),
          isDeleted: const drift.Value(false), // 🌟 إحياء العميل إذا كان محذوفاً (Soft Delete Restore)
        );
        await _localStorage.upsertContact(companion);
      } else {
        // 💡 الرقم غير موجود! نضيفه كعميل جديد تماماً ونولد له UUID جديد
        final companion = ContactsCompanion(
          id: drift.Value(_uuid.v4()), // 🌟 توليد ID فريد
          name: drift.Value(name),
          phone: drift.Value(phone),
        );
        await _localStorage.upsertContact(companion);
      }
    }
  }

  Future<void> deleteContact(Contact contact) async {
    // 🌟 تعديل: أصبح يعتمد على الحذف الناعم في الهاتف وفي السحابة
    await _localStorage.deleteContact(contact); // تحديث isDeleted = true محلياً
    try { await _cloudStorage.softDeleteContact(contact.id); } catch (_) {} // تحديث مباشر في السحابة
  }

  Future<void> updateContactGroup(Contact contact, String? groupId) async { // 🌟 String?
    await _localStorage.updateContactGroupDB(contact.id, groupId); 
  }

  // ==========================================
  // 3. قسم المجموعات والحملات 📅
  // ==========================================
  Future<List<Group>> getGroups() async {
    return await _localStorage.getAllGroups();
  }

  Future<void> addGroup(String name) async {
    await _localStorage.upsertGroup(GroupsCompanion(
      id: drift.Value(_uuid.v4()), // 🌟 توليد ID فريد
      name: drift.Value(name),
    ));
  }

  Future<void> deleteGroup(Group group) async {
    // 🌟 تعديل: أصبح يعتمد على الحذف الناعم
    await _localStorage.clearGroupFromContacts(group.id);
    await _localStorage.deleteGroup(group); // تحديث isDeleted = true محلياً
    try { await _cloudStorage.softDeleteGroup(group.id); } catch (_) {}
  }

  Future<void> updateGroup(Group group) async {
    await _localStorage.updateGroup(group);
  }

  Future<List<Schedule>> getSchedules() async {
    return await _localStorage.getAllSchedules();
  }

  /// 🌟 تمت إضافة targetDeviceId لدالة إنشاء الحملة
  Future<void> addSchedule({
    required String groupId, // 🌟 String
    required String message, 
    required int sendDay, 
    required int sendHour, 
    required int sendMinute,
    String? targetDeviceId, 
  }) async {
    final companion = SchedulesCompanion(
      id: drift.Value(_uuid.v4()), // 🌟 توليد ID فريد
      groupId: drift.Value(groupId), 
      message: drift.Value(message), 
      sendDay: drift.Value(sendDay),
      sendHour: drift.Value(sendHour), 
      sendMinute: drift.Value(sendMinute),
      targetDeviceId: drift.Value(targetDeviceId), 
    );
    await _localStorage.upsertSchedule(companion);
  }

  Future<void> deleteSchedule(Schedule schedule) async {
    // 🌟 تعديل: أصبح يعتمد على الحذف الناعم
    await _localStorage.deleteSchedule(schedule); // تحديث isDeleted = true محلياً
    try { await _cloudStorage.softDeleteSchedule(schedule.id); } catch (_) {}
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await _localStorage.updateSchedule(schedule);
  }

  // ==========================================
  // 4. قسم السجلات 📊
  // ==========================================
  Future<List<Message>> getMessageLogs() async {
    return await _localStorage.getAllMessages();
  }

  Future<void> addMessageLog({required String phone, required String body, required String type}) async {
    // 1. الحفظ في قاعدة البيانات المحلية (Drift)
    await _localStorage.upsertMessage(MessagesCompanion(
      id: drift.Value(_uuid.v4()), // 🌟 توليد ID فريد
      phone: drift.Value(phone), 
      body: drift.Value(body), 
      type: drift.Value(type), 
      messageDate: drift.Value(DateTime.now()), 
    ));

    // 2. 🚀 الرفع التلقائي للسحابة فوراً (لكي لا تضيع الرسالة)
    try {
      // نستدعي دالة المزامنة الشاملة لرفع هذا السجل الجديد
      await syncAllToCloud(); 
    } catch (e) {
      // في حال عدم وجود إنترنت وقت إرسال الـ SMS، ستبقى محفوظة محلياً
      // وسيتم رفعها لاحقاً عند فتح التطبيق
      print('تم حفظ الرسالة محلياً، سيتم رفعها لاحقاً لعدم توفر اتصال: $e');
    }
  }

  // ==========================================
  // 5. قسم المزامنة الشاملة ☁️
  // ==========================================
  Future<void> saveFcmToken(String token) async {
    // هذه الدالة تم حذفها سابقاً، يمكن إزالتها أو تركها فارغة، لأننا نعتمد على registerDevice
  }

  Future<void> syncAllToCloud() async {
    // 🌟 السحر: لكي نفهم الحذف الناعم، نطلب من قاعدة البيانات جلب (كل شيء) بما فيه المحذوف!
    // لو استخدمنا getAllContacts العادية، كانت ستخفي العملاء المحذوفين ولن يتم رفعهم للسحابة
    final groups = await _localStorage.select(_localStorage.groups).get();
    final contacts = await _localStorage.select(_localStorage.contacts).get();
    final schedules = await _localStorage.select(_localStorage.schedules).get();
    final messages = await _localStorage.select(_localStorage.messages).get(); 

    // 🌟 أضفنا حقل is_deleted لكي تعرف السحابة أننا قمنا בחذف شيء ما محلياً
    final groupsJson = groups.map((g) => {'id': g.id, 'name': g.name, 'is_deleted': g.isDeleted}).toList();
    final contactsJson = contacts.map((c) => {'id': c.id, 'name': c.name, 'phone': c.phone, 'group_id': c.groupId, 'is_deleted': c.isDeleted}).toList();
    
    final schedulesJson = schedules.map((s) => {
      'id': s.id,
      'group_id': s.groupId,
      'message': s.message,
      'send_day': s.sendDay,
      'send_hour': s.sendHour,
      'send_minute': s.sendMinute,
      'target_device_id': s.targetDeviceId, 
      'is_active': s.isActive, 
      'is_deleted': s.isDeleted // 🌟
    }).toList();

    final messagesJson = messages.map((m) => {'id': m.id, 'phone': m.phone, 'body': m.body, 'type': m.type, 'message_date': m.messageDate.toIso8601String()}).toList();

    await _cloudStorage.syncGroups(groupsJson);
    await _cloudStorage.syncContacts(contactsJson);
    await _cloudStorage.syncSchedules(schedulesJson);
    await _cloudStorage.syncMessages(messagesJson);

    await _cloudStorage.updateCloudSyncTime();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_sync_time', DateTime.now().toUtc().toIso8601String());
  }

  Future<void> downloadAllFromCloud() async {
    final cloudGroups = await _cloudStorage.fetchGroups();
    final cloudContacts = await _cloudStorage.fetchContacts();
    final cloudSchedules = await _cloudStorage.fetchSchedules();
    final cloudMessages = await _cloudStorage.fetchMessages();

    // 🌟 نقرأ حقل is_deleted القادم من السحابة ونحفظه محلياً ليختفي العنصر من الواجهة
    for (var row in cloudGroups) {
      try { await _localStorage.upsertGroup(GroupsCompanion(id: drift.Value(row['id'].toString()), name: drift.Value(row['name']), isDeleted: drift.Value(row['is_deleted'] ?? false))); } catch (_) {} 
    }

    for (var row in cloudContacts) {
      try { await _localStorage.upsertContact(ContactsCompanion(id: drift.Value(row['id'].toString()), name: drift.Value(row['name']), phone: drift.Value(row['phone']), groupId: drift.Value(row['group_id']?.toString()), isDeleted: drift.Value(row['is_deleted'] ?? false))); } catch (_) {}
    }

    for (var row in cloudSchedules) {
      try {
        await _localStorage.upsertSchedule(SchedulesCompanion(
          id: drift.Value(row['id'].toString()),
          groupId: drift.Value(row['group_id'].toString()),
          message: drift.Value(row['message']),
          sendHour: drift.Value(row['send_hour'] ?? 9),
          sendMinute: drift.Value(row['send_minute'] ?? 0),
          sendDay: drift.Value(row['send_day']),
          targetDeviceId: drift.Value(row['target_device_id']?.toString()), 
          lastSentDate: drift.Value(row['last_sent_date'] != null ? DateTime.parse(row['last_sent_date']) : null),
          isActive: drift.Value(row['is_active']),
          isDeleted: drift.Value(row['is_deleted'] ?? false), // 🌟
        ));
      } catch (_) {}
    }

    for (var row in cloudMessages) {
      try { await _localStorage.upsertMessage(MessagesCompanion(id: drift.Value(row['id'].toString()), phone: drift.Value(row['phone']), body: drift.Value(row['body']), type: drift.Value(row['type']), messageDate: drift.Value(DateTime.parse(row['message_date'])))); } catch (_) {}
    }
  }

  Future<bool> downloadIfCloudIsNewer() async {
    final cloudTime = await _cloudStorage.getCloudSyncTime();
    if (cloudTime == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final localTimeString = prefs.getString('local_sync_time');
    DateTime? localTime;
    if (localTimeString != null) localTime = DateTime.parse(localTimeString);

    if (localTime == null || cloudTime.isAfter(localTime)) {
      // ✅ نكتفي بالتنزيل، ودوال הـ Upsert في Drift ستتكفل بدمج البيانات دون حذف رسائلنا الجديدة
      await downloadAllFromCloud(); 
      await prefs.setString('local_sync_time', cloudTime.toIso8601String());
      return true; 
    }
    return false; 
  }
}