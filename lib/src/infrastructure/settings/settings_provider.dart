import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_settings_store.dart';

final settingsStoreProvider = Provider<SecureSettingsStore>((ref) {
  return SecureSettingsStore();
});
