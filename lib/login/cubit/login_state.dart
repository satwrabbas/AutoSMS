part of 'login_cubit.dart';

abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {} // جاري تسجيل الدخول

class LoginSuccess extends LoginState {} // تم بنجاح

class LoginError extends LoginState {
  LoginError({required this.message});
  final String message;
}