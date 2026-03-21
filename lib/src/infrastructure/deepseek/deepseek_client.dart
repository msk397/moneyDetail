import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deepSeekClientProvider = Provider<DeepSeekClient>((ref) {
  return DeepSeekClient();
});

class DeepSeekClient {
  DeepSeekClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<String> createChatCompletion({
    required String apiKey,
    required String model,
    required String prompt,
    String? baseUrl,
    double temperature = 0.3,
  }) async {
    final apiBase = _normalizeBaseUrl(baseUrl);
    final requestBody = {
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': temperature,
    };

    _logDebug('DeepSeek request: ${jsonEncode({
          'url': '$apiBase/chat/completions',
          'model': model,
          'promptPreview': _shorten(prompt),
        })}');

    late final Response<dynamic> response;
    try {
      response = await _dio.post(
        '$apiBase/chat/completions',
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );
    } on DioException catch (e) {
      _logDebug(
        'DeepSeek request failed: ${jsonEncode({
          'statusCode': e.response?.statusCode,
          'message': e.message,
          'response': _shorten(e.response?.data),
        })}',
      );
      rethrow;
    }

    _logDebug(
      'DeepSeek response: ${jsonEncode({
        'statusCode': response.statusCode,
        'data': _shorten(response.data),
      })}',
    );

    final choices = (response.data['choices'] as List<dynamic>?) ?? const [];
    if (choices.isEmpty) {
      return '';
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    return (message?['content'] as String?)?.trim() ?? '';
  }

  Future<String> createAdvice({
    required String apiKey,
    required String model,
    required String prompt,
    String? baseUrl,
  }) async {
    return createChatCompletion(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      baseUrl: baseUrl,
      temperature: 0.3,
    );
  }

  String _normalizeBaseUrl(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'https://api.deepseek.com';
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
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
