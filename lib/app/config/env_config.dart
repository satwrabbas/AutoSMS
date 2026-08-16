// lib/app/config/env_config.dart
abstract class EnvConfig {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Firebase Android Configuration
  static const String firebaseAndroidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const String firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  // Firebase Common Configuration
  static const String firebaseMessagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  // Firebase Windows Configuration
  static const String firebaseWindowsApiKey = String.fromEnvironment('FIREBASE_WINDOWS_API_KEY');
  static const String firebaseWindowsAppId = String.fromEnvironment('FIREBASE_WINDOWS_APP_ID');
  static const String firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const String firebaseMeasurementId = String.fromEnvironment('FIREBASE_MEASUREMENT_ID');
}