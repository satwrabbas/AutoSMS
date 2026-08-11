import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_repository/crm_repository.dart';
import 'package:cloud_storage_api/cloud_storage_api.dart';

part 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required CrmRepository repository})
      : _repository = repository,
        super(LoginInitial());

  final CrmRepository _repository;

  Future<void> signIn({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signIn(email: email, password: password);
      emit(LoginSuccess());
    } catch (e) {
      emit(LoginError(message: _translateError(e)));
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    emit(LoginLoading());
    try {
      await _repository.signUp(email: email, password: password);
      emit(LoginSuccess());
    } catch (e) {
      emit(LoginError(message: _translateError(e)));
    }
  }

  String _translateError(Object e) {
    final errorStr = e.toString().toLowerCase();

    if (errorStr.contains('socket') || 
        errorStr.contains('host lookup') || 
        errorStr.contains('network') || 
        errorStr.contains('connection') ||
        errorStr.contains('xmlhttprequest') || 
        errorStr.contains('clientexception')) {
      return 'errorNoInternet';
    }

    if (e is AuthException) {
      if (errorStr.contains('invalid login credentials')) {
        return 'errorInvalidCredentials';
      }
      if (errorStr.contains('user already registered')) {
        return 'errorUserAlreadyRegistered';
      }
      if (errorStr.contains('password should be at least')) {
        return 'errorWeakPassword';
      }
      if (errorStr.contains('rate limit')) {
        return 'errorRateLimit';
      }
      return e.message; 
    }

    return 'errorUnexpected';
  }
}