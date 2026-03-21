import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/expense_category.dart';
import '../infrastructure/db/app_database.dart';
import '../infrastructure/db/db_provider.dart';
import '../infrastructure/deepseek/deepseek_client.dart';
import '../infrastructure/settings/secure_settings_store.dart';
import '../infrastructure/settings/settings_provider.dart';

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final settings = ref.watch(settingsStoreProvider);
  final deepSeekClient = ref.watch(deepSeekClientProvider);
  return ExpenseService(db, settings, deepSeekClient);
});

class ExpenseService {
  ExpenseService(this._db, this._settings, this._deepSeekClient);

  final AppDatabase _db;
  final SecureSettingsStore _settings;
  final DeepSeekClient _deepSeekClient;

  static const confidenceThreshold = 0.75;

  Future<ParseExpenseResult> parseExpenseFromText(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return ParseExpenseResult(
        draft: _parseFallback(trimmed),
        deepSeekFailed: false,
      );
    }

    final apiKey = await _settings.read(SecureSettingsStore.deepSeekApiKeyKey);
    var model = await _settings.read(SecureSettingsStore.deepSeekModelKey);
    final baseUrl = await _settings.read(SecureSettingsStore.deepSeekBaseUrlKey);
    if (model.isEmpty) {
      model = 'deepseek-chat';
    }

    if (apiKey.isEmpty) {
      return ParseExpenseResult(
        draft: _parseFallback(trimmed),
        deepSeekFailed: false,
      );
    }

    try {
      final prompt = _buildParsePrompt(trimmed);
      final content = await _deepSeekClient.createChatCompletion(
        apiKey: apiKey,
        model: model,
        prompt: prompt,
        baseUrl: baseUrl,
        temperature: 0.0,
      );

      final normalized = _extractJson(content);
      final data = jsonDecode(normalized) as Map<String, dynamic>;

      final title = (data['title'] as String?)?.trim();
      final amount = ((data['amount'] as num?)?.toDouble() ?? 0).abs();
      final categoryText = (data['category'] as String?)?.trim() ?? '其他';
      final note = (data['note'] as String?)?.trim();
      final confidence = ((data['confidence'] as num?)?.toDouble() ?? 0.0)
          .clamp(0.0, 1.0);
      final spentAtText = (data['spentAt'] as String?)?.trim();
      final spentAt =
          DateTime.tryParse(spentAtText ?? '')?.toLocal() ?? DateTime.now();

      final category = ExpenseCategory.fromLabel(categoryText);

      return ParseExpenseResult(
        draft: ExpenseDraft(
          title: (title == null || title.isEmpty) ? trimmed : title,
          amount: amount,
          category: category,
          spentAt: spentAt,
          note: (note == null || note.isEmpty) ? trimmed : note,
          confidence: confidence,
        ),
        deepSeekFailed: false,
      );
    } catch (_) {
      return ParseExpenseResult(
        draft: _parseFallback(trimmed),
        deepSeekFailed: true,
      );
    }
  }

  Future<SavedExpenseRef> saveExpenseDraft(ExpenseDraft draft, String rawInput) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final normalizedAmount = draft.category.isIncome ? -draft.amount.abs() : draft.amount.abs();

    await _db.insertExpense(
      id: id,
      title: draft.title,
      amount: normalizedAmount,
      category: draft.category.label,
      spentAt: draft.spentAt,
      note: rawInput,
    );

    return SavedExpenseRef(
      id: id,
      title: draft.title,
      amount: normalizedAmount,
      category: draft.category.label,
      rawInput: rawInput,
    );
  }

  ExpenseDraft _parseFallback(String text) {
    final normalized = text.trim();
    final amountMatch = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(normalized);
    final amount = amountMatch == null ? 0.0 : double.parse(amountMatch.group(1)!);

    ExpenseCategory category = ExpenseCategory.other;
    if (RegExp(r'收入|工资|薪资|奖金|报销|退款|收款|回款').hasMatch(normalized)) {
      category = ExpenseCategory.income;
    } else if (RegExp(r'餐|饭|吃|饮|奶茶').hasMatch(normalized)) {
      category = ExpenseCategory.meal;
    } else if (RegExp(r'地铁|打车|公交|高铁|油费').hasMatch(normalized)) {
      category = ExpenseCategory.transport;
    } else if (RegExp(r'学|课程|书').hasMatch(normalized)) {
      category = ExpenseCategory.study;
    } else if (RegExp(r'电费|水费|房租|物业|保险').hasMatch(normalized)) {
      category = ExpenseCategory.payment;
    } else if (RegExp(r'电影|游戏|唱歌').hasMatch(normalized)) {
      category = ExpenseCategory.entertainment;
    } else if (RegExp(r'买|购物|衣服|鞋').hasMatch(normalized)) {
      category = ExpenseCategory.shopping;
    }

    return ExpenseDraft(
        title: normalized.isEmpty
          ? (category.isIncome ? '未命名收入' : '未命名支出')
          : normalized,
      amount: amount,
      category: category,
      spentAt: DateTime.now(),
      note: normalized,
      confidence: 0.55,
    );
  }

  String _buildParsePrompt(String rawInput) {
    return '''
你是记账解析器。请把用户输入的账单语句解析成 JSON，不要输出任何解释。

分类仅允许：收入、餐饮、购物、娱乐、交通、缴费、学习、其他。
如果无法判断类别，填“其他”。
金额必须是数字，单位人民币元。

输出字段必须完整：
{
  "title": "string",
  "amount": 0,
  "category": "收入|餐饮|购物|娱乐|交通|缴费|学习|其他",
  "spentAt": "ISO-8601时间字符串，无法识别就用当前时间",
  "note": "string",
  "confidence": 0.0
}

用户输入：$rawInput
''';
  }

  String _extractJson(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('```')) {
      final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(trimmed);
      if (codeBlock != null) {
        return codeBlock.group(1)!.trim();
      }
    }
    return trimmed;
  }
}

class ParseExpenseResult {
  ParseExpenseResult({required this.draft, required this.deepSeekFailed});

  final ExpenseDraft draft;
  final bool deepSeekFailed;
}

class ExpenseDraft {
  ExpenseDraft({
    required this.title,
    required this.amount,
    required this.category,
    required this.spentAt,
    required this.note,
    required this.confidence,
  });

  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime spentAt;
  final String note;
  final double confidence;

  ExpenseDraft copyWith({
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? spentAt,
    String? note,
    double? confidence,
  }) {
    return ExpenseDraft(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      spentAt: spentAt ?? this.spentAt,
      note: note ?? this.note,
      confidence: confidence ?? this.confidence,
    );
  }
}

class SavedExpenseRef {
  SavedExpenseRef({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.rawInput,
  });

  final String id;
  final String title;
  final double amount;
  final String category;
  final String rawInput;
}
