// lib/app/config/env_config.dart

abstract class EnvConfig {
  // Supabase Configuration
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '***REMOVED_SUPABASE_URL***',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        '***REMOVED_SUPABASE_KEY***',
  );

  // Firebase Android Configuration
  static const String firebaseAndroidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSyDmGPNAbt-8BzdXgpR5GMAhw7xJW3WpkQ0',
  );

  static const String firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:1065487711505:android:1ff8c28b0fd1a56b07e0b0',
  );

  // Firebase Common Configuration
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '1065487711505',
  );

  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'auto-sms-crm',
  );

  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'auto-sms-crm.firebasestorage.app',
  );

  // Firebase Windows Configuration
  static const String firebaseWindowsApiKey = String.fromEnvironment(
    'FIREBASE_WINDOWS_API_KEY',
    defaultValue: 'AIzaSyC6fmsc3z-51K9k35-49XVlTvYL057y-9M',
  );

  static const String firebaseWindowsAppId = String.fromEnvironment(
    'FIREBASE_WINDOWS_APP_ID',
    defaultValue: '1:1065487711505:web:598af3bed38a349707e0b0',
  );

  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'auto-sms-crm.firebaseapp.com',
  );

  static const String firebaseMeasurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
    defaultValue: 'G-BBH13MWQZ1',
  );
}