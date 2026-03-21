import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class NotionApiClient {
  NotionApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<NotionQueryResult> queryDatabasePages({
    required String token,
    required String databaseId,
    String? startCursor,
    int pageSize = 100,
    String sortProperty = 'Created time',
    String sortDirection = 'descending',
  }) async {
    final requestBody = {
      'sorts': [
        {
          'property': sortProperty,
          'direction': sortDirection,
        }
      ],
      'page_size': pageSize,
      if (startCursor != null && startCursor.isNotEmpty)
        'start_cursor': startCursor,
    };

    _logDebug('Notion query request: ${jsonEncode({
          'databaseId': databaseId,
          'body': requestBody,
        })}');

    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        'https://api.notion.com/v1/databases/$databaseId/query',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': '2022-06-28',
            'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      _logDebug(
        'Notion query failed: ${jsonEncode({
          'statusCode': e.response?.statusCode,
          'message': e.message,
          'response': _shorten(e.response?.data),
        })}',
      );
      rethrow;
    }

    _logDebug(
      'Notion query response: ${jsonEncode({
        'statusCode': response.statusCode,
        'data': _shorten(response.data),
      })}',
    );

    final data = response.data as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? const [])
        .map((item) => item as Map<String, dynamic>)
        .toList();

    return NotionQueryResult(
      results: results,
      hasMore: data['has_more'] == true,
      nextCursor: data['next_cursor'] as String?,
    );
  }

  Future<String?> createPage({
    required String token,
    required String databaseId,
    required Map<String, dynamic> properties,
  }) async {
    final requestBody = {
      'parent': {'database_id': databaseId},
      'properties': properties,
    };
    _logDebug('Notion create page request: ${jsonEncode(requestBody)}');
    try {
      final response = await _dio.post(
        'https://api.notion.com/v1/pages',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Notion-Version': '2022-06-28',
            'Content-Type': 'application/json',
          },
        ),
      );
      _logDebug(
        'Notion create page response: ${jsonEncode({
          'statusCode': response.statusCode,
          'data': _shorten(response.data),
        })}',
      );
      final data = response.data as Map<String, dynamic>?;
      return data?['id'] as String?;
    } on DioException catch (e) {
      _logDebug(
        'Notion create page failed: ${jsonEncode({
          'statusCode': e.response?.statusCode,
          'message': e.message,
          'response': _shorten(e.response?.data),
        })}',
      );
      rethrow;
    }
  }

  void _logDebug(String message) {
    if (!kDebugMode) return;
    debugPrint(message);
  }

  String _shorten(dynamic value) {
    final text = value == null ? '' : value.toString();
    if (text.length <= 2000) {
      return text;
    }
    return '${text.substring(0, 2000)}...<truncated>';
  }
}

class NotionQueryResult {
  NotionQueryResult({
    required this.results,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<Map<String, dynamic>> results;
  final bool hasMore;
  final String? nextCursor;
}
