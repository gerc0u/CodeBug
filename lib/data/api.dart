import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, [this.status = 0]);
  final String message;
  final int status;
  @override
  String toString() => message;
}

class CodeBugApi {
  CodeBugApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _defaultUrl;
  static String get _defaultUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return Uri.base.origin;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  final http.Client _client;
  final String baseUrl;
  String? token;
  VoidCallback? onUnauthorized;
  Future<dynamic> request(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl/api$path'));
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await (() async {
        return http.Response.fromStream(await _client.send(request));
      })().timeout(const Duration(seconds: 15));
      if (request.headers['Authorization'] != null &&
          request.headers['Authorization'] != 'Bearer $token') {
        throw ApiException('Аккаунт изменился. Повтори действие.', 401);
      }
      final dynamic data = response.body.isEmpty
          ? null
          : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        if (response.statusCode == 401 &&
            token != null &&
            request.headers['Authorization'] == 'Bearer $token') {
          onUnauthorized?.call();
        }
        final detail = data is Map ? data['detail'] : null;
        throw ApiException(
          detail is String ? detail : 'Проверь введённые данные',
          response.statusCode,
        );
      }
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('Сервер не ответил. Проверь подключение и повтори.');
    } catch (_) {
      throw ApiException(
        'Нет соединения с сервером. Запусти сервер CodeBug и повтори.',
      );
    }
  }

  void close() => _client.close();
}
