import 'package:supabase_flutter/supabase_flutter.dart';

/// 🌟 الكلاس المحدث ليتعامل مع بيانات كل مستخدم على حدة
class CloudStorageClient {
  CloudStorageClient({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabaseClient;

  // ==========================================
  // 1. قسم المصادقة (Authentication)
  // ==========================================
  Future<void> signIn({required String email, required String password}) async {
    await _supabaseClient.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp({required String email, required String password}) async {
    await _supabaseClient.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _supabaseClient.auth.onAuthStateChange;
  Session? get currentSession => _supabaseClient.auth.currentSession;
  String? get _currentUserId => _supabaseClient.auth.currentUser?.id;

  // ==========================================
  // 2. 🌟 قسم إدارة الأجهزة (Device Management)
  // ==========================================

  /// تسجيل الجهاز أو استعادته من الموت باستخدام بصمة الأندرويد (Hardware ID)
  Future<String?> registerDevice({
    required String deviceName, 
    required String fcmToken, 
    required String hardwareId,
  }) async {
    if (_currentUserId == null) return null;

    final data = {
      'user_id': _currentUserId,
      'device_name': deviceName,
      'fcm_token': fcmToken,
      'hardware_id': hardwareId, 
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      final existingDevice = await _supabaseClient
          .from('user_tokens')
          .select('device_id')
          .eq('user_id', _currentUserId!)
          .eq('hardware_id', hardwareId) 
          .maybeSingle();

      if (existingDevice != null) {
        // الهاتف عاد من الموت (حُذف وتمت إعادة تثبيته)!
        final oldId = existingDevice['device_id'];
        data['device_id'] = oldId;
        
        await _supabaseClient.from('user_tokens').upsert(data);
        return oldId as String; 
      } else {
        // هاتف جديد كلياً
        final response = await _supabaseClient.from('user_tokens').insert(data).select().single();
        return response['device_id'] as String;
      }
    } catch (e) {
      throw 'حدث خطأ في تسجيل الجهاز: $e';
    }
  }

  Future<void> removeDevice(String deviceId) async {
    if (_currentUserId == null) return;
    await _supabaseClient.from('user_tokens').delete().eq('device_id', deviceId);
  }

  Future<List<Map<String, dynamic>>> fetchDevices() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('user_tokens').select().eq('user_id', _currentUserId!);
  }

  // ==========================================
  // 3. 🌟 قسم الحذف الناعم (Soft Delete)
  // ==========================================
  
  Future<void> softDeleteGroup(String id) async {
    if (_currentUserId == null) return;
    await _supabaseClient.from('groups').update({'is_deleted': true}).eq('id', id).eq('user_id', _currentUserId!);
  }

  Future<void> softDeleteContact(String id) async {
    if (_currentUserId == null) return;
    await _supabaseClient.from('contacts').update({'is_deleted': true}).eq('id', id).eq('user_id', _currentUserId!);
  }

  Future<void> softDeleteSchedule(String id) async {
    if (_currentUserId == null) return;
    await _supabaseClient.from('schedules').update({'is_deleted': true}).eq('id', id).eq('user_id', _currentUserId!);
  }

  // ==========================================
  // 4. 🔄 قسم المزامنة (الرفع - Upload)
  // ==========================================

  Future<void> syncGroups(List<Map<String, dynamic>> groups) async {
    if (_currentUserId == null || groups.isEmpty) return;
    final data = groups.map((g) => {...g, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('groups').upsert(data);
  }

  Future<void> syncContacts(List<Map<String, dynamic>> contacts) async {
    if (_currentUserId == null || contacts.isEmpty) return;
    final data = contacts.map((c) => {...c, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('contacts').upsert(data);
  }

  Future<void> syncSchedules(List<Map<String, dynamic>> schedules) async {
    if (_currentUserId == null || schedules.isEmpty) return;
    final data = schedules.map((s) => {...s, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('schedules').upsert(data);
  }

  Future<void> syncMessages(List<Map<String, dynamic>> messages) async {
    if (_currentUserId == null || messages.isEmpty) return;
    final data = messages.map((m) => {...m, 'user_id': _currentUserId}).toList();
    await _supabaseClient.from('messages').upsert(data);
  }

  // ==========================================
  // 5. 📥 قسم جلب البيانات (التنزيل - Download)
  // ==========================================

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('groups').select().eq('user_id', _currentUserId!);
  }
  
  Future<List<Map<String, dynamic>>> fetchContacts() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('contacts').select().eq('user_id', _currentUserId!);
  }
  
  Future<List<Map<String, dynamic>>> fetchSchedules() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('schedules').select().eq('user_id', _currentUserId!);
  }
  
  Future<List<Map<String, dynamic>>> fetchMessages() async {
    if (_currentUserId == null) return[];
    return await _supabaseClient.from('messages').select().eq('user_id', _currentUserId!);
  }

  // ==========================================
  // 6. ⏱️ قسم تتبع تاريخ التحديثات (Sync Metadata)
  // ==========================================

  Future<void> updateCloudSyncTime() async {
    if (_currentUserId == null) return;
    await _supabaseClient.from('sync_metadata').upsert({
      'user_id': _currentUserId,
      'last_updated_at': DateTime.now().toUtc().toIso8601String(), 
    });
  }

  Future<DateTime?> getCloudSyncTime() async {
    if (_currentUserId == null) return null;
    
    final response = await _supabaseClient
        .from('sync_metadata')
        .select('last_updated_at')
        .eq('user_id', _currentUserId!)
        .maybeSingle(); 

    if (response != null && response['last_updated_at'] != null) {
      return DateTime.parse(response['last_updated_at']);
    }
    return null;
  }
}