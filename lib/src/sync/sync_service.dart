import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/db/app_database.dart';
import '../infrastructure/db/db_provider.dart';
import '../infrastructure/notion/notion_api_client.dart';
import '../infrastructure/settings/secure_settings_store.dart';
import '../infrastructure/settings/settings_provider.dart';

final notionApiClientProvider = Provider<NotionApiClient>((ref) {
  return NotionApiClient();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(appDatabaseProvider),
    settings: ref.watch(settingsStoreProvider),
    notionApiClient: ref.watch(notionApiClientProvider),
  );
});

class SyncService {
  SyncService({
    required this.db,
    required this.settings,
    required this.notionApiClient,
  });

  final AppDatabase db;
  final SecureSettingsStore settings;
  final NotionApiClient notionApiClient;

  Future<String> debugPreviewNotionResponse() async {
    final notionToken = await settings.read(SecureSettingsStore.notionTokenKey);
    final databaseId =
        await settings.read(SecureSettingsStore.notionDatabaseIdKey);
    if (notionToken.isEmpty || databaseId.isEmpty) {
      return 'Notion Token 或 Database ID 为空';
    }

    final result = await notionApiClient.queryDatabasePages(
      token: notionToken,
      databaseId: databaseId,
      pageSize: 3,
    );

    final payload = {
      'resultsCount': result.results.length,
      'hasMore': result.hasMore,
      'nextCursor': result.nextCursor,
      'sampleRows': result.results.take(2).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<int> syncPendingCreates() async {
    final notionToken = await settings.read(SecureSettingsStore.notionTokenKey);
    final databaseId =
        await settings.read(SecureSettingsStore.notionDatabaseIdKey);
    if (notionToken.isEmpty || databaseId.isEmpty) {
      return 0;
    }

    final pending = await (db.select(db.expenses)
          ..where((tbl) => tbl.syncState.equals('PENDING_CREATE')))
        .get();

    var pushed = 0;
    for (final expense in pending) {
      try {
        final notionPageId = await notionApiClient.createPage(
          token: notionToken,
          databaseId: databaseId,
          properties: {
            'Name': {
              'title': [
                {
                  'text': {'content': expense.title}
                }
              ]
            },
            'Price': {'number': expense.amount},
            'Category': {
              'select': {'name': expense.category}
            },
          },
        );

        await (db.update(db.expenses)..where((tbl) => tbl.id.equals(expense.id))).write(
          ExpensesCompanion(
            notionPageId: Value(notionPageId),
            syncState: const Value('SYNCED'),
            updatedAt: Value(DateTime.now()),
          ),
        );
        pushed += 1;
      } catch (_) {
        // Keep pending state for the next background sync attempt.
      }
    }

    return pushed;
  }

  Future<int> pullAllFromNotion() async {
    final notionToken = await settings.read(SecureSettingsStore.notionTokenKey);
    final databaseId =
        await settings.read(SecureSettingsStore.notionDatabaseIdKey);
    final lastPulledId =
        await settings.read(SecureSettingsStore.notionLastPulledIdKey);
    if (notionToken.isEmpty || databaseId.isEmpty) {
      return 0;
    }

    var cursor = '';
    var hasMore = true;
    var pulled = 0;
    var reachedLastPulledId = false;
    String? newestSeenId;
    var firstPage = true;

    while (hasMore && !reachedLastPulledId) {
      final result = await notionApiClient.queryDatabasePages(
        token: notionToken,
        databaseId: databaseId,
        startCursor: cursor.isEmpty ? null : cursor,
        pageSize: 100,
      );

      if (firstPage && result.results.isNotEmpty) {
        newestSeenId = result.results.first['id'] as String?;
        firstPage = false;
      }

      for (final row in result.results) {
        final props = row['properties'] as Map<String, dynamic>? ?? const {};

        final notionPageId = row['id'] as String?;
        if (notionPageId == null || notionPageId.isEmpty) {
          continue;
        }

        if (lastPulledId.isNotEmpty && notionPageId == lastPulledId) {
          reachedLastPulledId = true;
          break;
        }

        final title = _extractTitle(props);
        final amount = _extractPrice(props);
        final category = _extractCategory(props);
        final spentAt = _extractDate(props) ??
            DateTime.tryParse((row['created_time'] as String?) ?? '')?.toLocal() ??
            DateTime.now();

        await db.upsertExpenseFromNotion(
          notionPageId: notionPageId,
          title: title,
          amount: amount,
          category: category,
          spentAt: spentAt,
          note: title,
        );
        pulled += 1;
      }

      hasMore = result.hasMore;
      cursor = result.nextCursor ?? '';
    }

    if (newestSeenId != null && newestSeenId.isNotEmpty) {
      await settings.save(SecureSettingsStore.notionLastPulledIdKey, newestSeenId);
    }

    return pulled;
  }

  Future<SyncSummary> syncAll() async {
    final pushed = await syncPendingCreates();
    final pulled = await pullAllFromNotion();
    return SyncSummary(pushed: pushed, pulled: pulled);
  }

  String _extractTitle(Map<String, dynamic> properties) {
    final name = properties['Name'] as Map<String, dynamic>?;
    final title = name?['title'] as List<dynamic>?;
    if (title == null || title.isEmpty) {
      return 'Notion导入账单';
    }
    final text = title.first['plain_text'] as String?;
    return (text == null || text.isEmpty) ? 'Notion导入账单' : text;
  }

  double _extractPrice(Map<String, dynamic> properties) {
    final price = properties['Price'] as Map<String, dynamic>?;
    final number = price?['number'] as num?;
    return number?.toDouble() ?? 0.0;
  }

  String _extractCategory(Map<String, dynamic> properties) {
    final category = properties['Category'] as Map<String, dynamic>?;
    final select = category?['select'] as Map<String, dynamic>?;
    final name = select?['name'] as String?;
    return (name == null || name.isEmpty) ? '其他' : name;
  }

  DateTime? _extractDate(Map<String, dynamic> properties) {
    final date = properties['Date'] as Map<String, dynamic>?;
    final dateInner = date?['date'] as Map<String, dynamic>?;
    final start = dateInner?['start'] as String?;
    return DateTime.tryParse(start ?? '')?.toLocal();
  }
}

class SyncSummary {
  SyncSummary({required this.pushed, required this.pulled});

  final int pushed;
  final int pulled;
}
