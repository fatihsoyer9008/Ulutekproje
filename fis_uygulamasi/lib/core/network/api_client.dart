import 'dart:async';

import 'package:dio/dio.dart';

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
    this.dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static const _retriedKey = 'auth_request_retried';
  static const _refreshPath = '/api/v1/auth/refresh';

  final Dio dio;
  final Dio _refreshDio;
  final TokenStorage _tokenStorage;

  String? _accessToken;
  Future<AuthTokenBundle?>? _refreshOperation;

  bool get hasAccessToken => _accessToken != null;

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
      handler.next(error);
      return;
    }

    try {
      final session = await refreshSession();
      if (session == null) {
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
    dio.close(force: true);
    _refreshDio.close(force: true);
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
