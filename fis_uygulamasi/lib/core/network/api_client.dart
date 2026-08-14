import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_token_storage.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    Dio? dio,
    Dio? refreshDio,
    // ignore: prefer_initializing_formals
  }) : _tokenStorage = tokenStorage,
       dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 30),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           ),
       _refreshDio =
           refreshDio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           ) {
    this.dio.interceptors.add(const _AuthDebugInterceptor());
    this.dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const _retriedKey = 'auth_request_retried';
  static const _refreshPath = '/api/v1/auth/refresh';

  final Dio dio;
  final Dio _refreshDio;
  final TokenStorage _tokenStorage;
  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast(sync: true);

  String? _accessToken;
  Future<AuthTokenBundle?>? _refreshOperation;
  bool _unauthorizedNotified = false;

  bool get hasAccessToken => _accessToken != null;
  Stream<void> get unauthorizedEvents => _unauthorizedController.stream;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _accessToken;
    if (token != null && options.extra['skipAuth'] != true) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final shouldRefresh =
        error.response?.statusCode == 401 &&
        request.path != _refreshPath &&
        request.extra['skipAuth'] != true &&
        request.extra[_retriedKey] != true;

    if (!shouldRefresh) {
      if (error.response?.statusCode == 401 &&
          request.path != _refreshPath &&
          request.extra['skipAuth'] != true &&
          request.extra[_retriedKey] == true) {
        await clearSession();
        _notifyUnauthorized();
      }
      handler.next(error);
      return;
    }

    try {
      final session = await refreshSession();
      if (session == null) {
        await clearSession();
        _notifyUnauthorized();
        handler.next(error);
        return;
      }

      final response = await dio.fetch<dynamic>(
        request.copyWith(
          headers: {
            ...request.headers,
            'Authorization': 'Bearer ${session.accessToken}',
          },
          extra: {...request.extra, _retriedKey: true},
        ),
      );
      handler.resolve(response);
    } on Exception {
      handler.next(error);
    }
  }

  Future<AuthTokenBundle?> refreshSession() {
    final running = _refreshOperation;
    if (running != null) return running;

    final operation = _performRefresh();
    _refreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
    });
  }

  Future<AuthTokenBundle?> _performRefresh() async {
    String? refreshToken;
    try {
      refreshToken = await _tokenStorage.readRefreshToken();
    } on TokenStorageException {
      await clearSession();
      return null;
    }
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        _refreshPath,
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (data == null) return null;
      final bundle = AuthTokenBundle.fromJson(data);
      await setSession(bundle);
      return bundle;
    } on Exception {
      await clearSession();
      return null;
    }
  }

  Future<void> setSession(AuthTokenBundle bundle) async {
    await _tokenStorage.writeRefreshToken(bundle.refreshToken);
    _accessToken = bundle.accessToken;
    _unauthorizedNotified = false;
  }

  Future<void> clearSession() async {
    _accessToken = null;
    try {
      await _tokenStorage.deleteRefreshToken();
    } on TokenStorageException {
      // Token RAM'den silindi. Güvenli depolama hatasında düz depoya düşülmez.
    }
  }

  Future<String?> readRefreshToken() => _tokenStorage.readRefreshToken();

  void close() {
    _unauthorizedController.close();
    dio.close(force: true);
    _refreshDio.close(force: true);
  }

  void _notifyUnauthorized() {
    if (_unauthorizedNotified || _unauthorizedController.isClosed) return;
    _unauthorizedNotified = true;
    _unauthorizedController.add(null);
  }
}

class _AuthDebugInterceptor extends Interceptor {
  const _AuthDebugInterceptor();

  static bool _isAuthPath(String path) => path.startsWith('/api/v1/auth/');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode && _isAuthPath(options.path)) {
      debugPrint(
        '[AuthNetwork] REQUEST ${options.method} ${options.uri}\n'
        'headers=${_sanitize(options.headers)}\n'
        'body=${_sanitize(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode && _isAuthPath(response.requestOptions.path)) {
      debugPrint(
        '[AuthNetwork] RESPONSE '
        '${response.requestOptions.method} ${response.requestOptions.uri} '
        'status=${response.statusCode}\n'
        'body=${_sanitize(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    if (kDebugMode && _isAuthPath(error.requestOptions.path)) {
      debugPrint(
        '[AuthNetwork] ERROR '
        '${error.requestOptions.method} ${error.requestOptions.uri} '
        'type=${error.type.name} '
        'status=${error.response?.statusCode}\n'
        'message=${error.message}\n'
        'response=${_sanitize(error.response?.data)}',
      );
    }
    handler.next(error);
  }

  static Object? _sanitize(Object? value, [String? key]) {
    if (value is Map) {
      return value.map(
        (mapKey, mapValue) =>
            MapEntry(mapKey.toString(), _sanitize(mapValue, mapKey.toString())),
      );
    }
    if (value is Iterable) {
      return value.map((item) => _sanitize(item)).toList();
    }
    if (value is String) {
      final normalizedKey = key?.toLowerCase() ?? '';
      if (normalizedKey == 'authorization') return '<redacted>';
      if (normalizedKey.contains('token') ||
          normalizedKey.contains('password') ||
          normalizedKey.contains('secret') ||
          normalizedKey == 'authorization_code') {
        return '<redacted length=${value.length}>';
      }
      if (normalizedKey == 'nonce') {
        return '<redacted length=${value.length}>';
      }
      if (normalizedKey == 'email') {
        final separator = value.indexOf('@');
        if (separator > 1) {
          return '${value.substring(0, 1)}***${value.substring(separator)}';
        }
        return '<redacted email>';
      }
    }
    return value;
  }
}

class AuthTokenBundle {
  const AuthTokenBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  factory AuthTokenBundle.fromJson(Map<String, dynamic> json) {
    final accessToken = json['access_token'];
    final refreshToken = json['refresh_token'];
    final user = json['user'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty ||
        user is! Map) {
      throw const FormatException('Geçersiz oturum cevabı.');
    }
    return AuthTokenBundle(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: Map<String, dynamic>.from(user),
    );
  }
}
