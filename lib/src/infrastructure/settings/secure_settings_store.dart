import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSettingsStore {
  SecureSettingsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // Stable storage keys (do not put real secrets here).
  static const notionTokenKey = 'notion_token';
  static const notionDatabaseIdKey = 'notion_database_id';
  static const notionLastPulledIdKey = 'notion_last_pulled_id';
  static const deepSeekApiKeyKey = 'deepseek_api_key';
  static const deepSeekModelKey = 'deepseek_model';
  static const deepSeekBaseUrlKey = 'deepseek_base_url';
  static const monthlyBudgetKey = 'monthly_budget';

  final FlutterSecureStorage _storage;
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    resetOnError: true,
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  Future<void> save(String key, String value) {
    return _storage.write(
      key: key,
      value: value.trim(),
      aOptions: _androidOptions,
      iOptions: _iosOptions,
    );
  }

  Future<String> read(String key) async {
    return await _storage.read(
          key: key,
          aOptions: _androidOptions,
          iOptions: _iosOptions,
        ) ??
        '';
  }
}
