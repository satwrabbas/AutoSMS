import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart'; // لجلب AuthException

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required CrmRepository repository})
      : _repository = repository,
        super(LoginInitial());

  final CrmRepository _repository;

  /// 🌟 دالة تسجيل الدخول
  Future<void> signIn({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signIn(email: email, password: password);
      emit(LoginSuccess());
    } catch (e) {
      // نمرر أي خطأ مهما كان للمترجم الذكي
      emit(LoginError(message: _translateError(e)));
    }
  }

  /// 🌟 دالة إنشاء حساب جديد
  Future<void> signUp({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signUp(email: email, password: password);
      emit(LoginSuccess());
    } catch (e) {
      // نمرر أي خطأ مهما كان للمترجم الذكي
      emit(LoginError(message: _translateError(e)));
    }
  }

  /// 🌟 المترجم الذكي الموحد لاصطياد جميع أنواع الأخطاء
  String _translateError(Object e) {
    final errorStr = e.toString().toLowerCase();
    
    // 1. التحقق من انقطاع الإنترنت (نصطادها أولاً مهما كان نوع الخطأ من Supabase أو غيرها)
    if (errorStr.contains('socket') || 
        errorStr.contains('host lookup') || 
        errorStr.contains('network') || 
        errorStr.contains('connection') ||
        errorStr.contains('xmlhttprequest') || // ضروري جداً لاصطياد أخطاء الإنترنت إذا كنت تستخدم Flutter Web
        errorStr.contains('clientexception')) {
      return '❌ لا يوجد اتصال بالإنترنت! يرجى التحقق من الشبكة والمحاولة مجدداً.';
    }

    // 2. التحقق من أخطاء Supabase المحددة
    if (e is AuthException) {
      if (errorStr.contains('invalid login credentials')) {
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة ❌';
      }
      if (errorStr.contains('user already registered')) {
        return 'هذا البريد الإلكتروني مسجل مسبقاً لدينا! 📧';
      }
      if (errorStr.contains('password should be at least')) {
        return 'كلمة المرور ضعيفة، يجب أن تكون 6 أحرف على الأقل 🔐';
      }
      if (errorStr.contains('rate limit')) {
        return 'حاولت الكثير من المرات. يرجى الانتظار قليلاً ⏳';
      }
      
      // إذا كان خطأ من Supabase لم نترجمه
      return 'حدث خطأ في المصادقة: ${e.message}'; 
    }

    // 3. أي خطأ آخر غريب
    return 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.';
  }
}