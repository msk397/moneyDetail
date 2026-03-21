import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/db/app_database.dart';
import '../infrastructure/db/db_provider.dart';
import '../infrastructure/deepseek/deepseek_client.dart';
import '../infrastructure/settings/secure_settings_store.dart';
import '../infrastructure/settings/settings_provider.dart';

final adviceTriggerServiceProvider = Provider<AdviceTriggerService>((ref) {
  return AdviceTriggerService(
    db: ref.watch(appDatabaseProvider),
    settings: ref.watch(settingsStoreProvider),
    deepSeekClient: ref.watch(deepSeekClientProvider),
  );
});

class AdviceResult {
  AdviceResult({
    required this.content,
    required this.hash,
    required this.generatedAt,
    required this.usedCache,
  });

  final String content;
  final String hash;
  final DateTime generatedAt;
  final bool usedCache;
}

class AdviceTriggerService {
  AdviceTriggerService({
    required this.db,
    required this.settings,
    required this.deepSeekClient,
  });

  final AppDatabase db;
  final SecureSettingsStore settings;
  final DeepSeekClient deepSeekClient;

  static const _hashKey = 'advice_source_hash';
  static const _contentKey = 'advice_content';
  static const _generatedAtKey = 'advice_generated_at';

  Future<AdviceResult> getAdvice({bool forceRefresh = false}) async {
    final sourceHash = await _buildSourceHash();
    final cachedHash = await settings.read(_hashKey);
    final cachedContent = await settings.read(_contentKey);
    final cachedGeneratedAt = await settings.read(_generatedAtKey);

    if (!forceRefresh && sourceHash == cachedHash && cachedContent.isNotEmpty) {
      return AdviceResult(
        content: cachedContent,
        hash: cachedHash,
        generatedAt: DateTime.tryParse(cachedGeneratedAt) ?? DateTime.now(),
        usedCache: true,
      );
    }

    final apiKey = await settings.read(SecureSettingsStore.deepSeekApiKeyKey);
    final model = await settings.read(SecureSettingsStore.deepSeekModelKey);
    final baseUrl = await settings.read(SecureSettingsStore.deepSeekBaseUrlKey);
    if (apiKey.isEmpty || model.isEmpty) {
      return AdviceResult(
        content: '请先在设置中填写 DeepSeek Key 和模型名。',
        hash: sourceHash,
        generatedAt: DateTime.now(),
        usedCache: false,
      );
    }

    final prompt = await _buildPrompt();
    final content = await deepSeekClient.createAdvice(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      baseUrl: baseUrl,
    );

    final generatedAt = DateTime.now();
    await settings.save(_hashKey, sourceHash);
    await settings.save(_contentKey, content);
    await settings.save(_generatedAtKey, generatedAt.toIso8601String());

    return AdviceResult(
      content: content,
      hash: sourceHash,
      generatedAt: generatedAt,
      usedCache: false,
    );
  }

  Future<String> _buildSourceHash() async {
    final rows = await (db.select(db.expenses)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.updatedAt)]))
        .get();
    final payload = rows
        .map((e) => {
              'id': e.id,
              'amount': e.amount,
              'category': e.category,
              'updatedAt': e.updatedAt.toIso8601String(),
            })
        .toList();

    return sha256.convert(utf8.encode(jsonEncode(payload))).toString();
  }

  Future<String> _buildPrompt() async {
    final rows = await (db.select(db.expenses)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.spentAt)]))
        .get();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final monthRows = rows
        .where((e) => e.spentAt.isAfter(monthStart.subtract(const Duration(microseconds: 1))) && e.spentAt.isBefore(monthEnd))
        .toList();
    final monthExpense = monthRows
        .where((e) => e.amount > 0)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final budgetRaw = await settings.read(SecureSettingsStore.monthlyBudgetKey);
    final monthBudget = double.tryParse(budgetRaw);

    final sample = rows.take(200).map((e) {
      return {
        'title': e.title,
        'amount': e.amount,
        'category': e.category,
        'spentAt': e.spentAt.toIso8601String(),
      };
    }).toList();

    return '''
你是一名财务规划助手。请基于以下账单数据给出 3 条可执行建议。
要求：
1. 每条建议明确到行为层面，不要空话。
2. 建议重点围绕“控支、预算执行、分类优化”。
3. 结合本月支出、预算执行情况与分类占比。
4. 结尾给出一段“下周执行清单”（3-5 条）。

本月概要：
- 本月支出：$monthExpense
- 本月总预算：${monthBudget ?? '未设置'}

账单数据：
${jsonEncode(sample)}
''';
  }
}
