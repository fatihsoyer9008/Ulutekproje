import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../domain/auth_user.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({required ApiClient apiClient, GoogleSignIn? googleSignIn})
    // ignore: prefer_initializing_formals
    : _apiClient = apiClient,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email.trim(), 'password': password},
        options: Options(extra: const {'skipAuth': true}),
      );
      return _saveTokenResponse(response.data);
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error, 'Giriş yapılamadı.'));
    }
  }

  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      return response.data?['message'] as String? ??
          'Doğrulama bağlantısı e-posta adresinize gönderildi.';
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error, 'Kayıt oluşturulamadı.'));
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/forgot-password',
        data: {'email': email.trim()},
        options: Options(extra: const {'skipAuth': true}),
      );
      return response.data?['message'] as String? ??
          'Uygunsa sıfırlama bağlantısı e-posta adresinize gönderildi.';
    } on DioException catch (error) {
      throw AuthException(
        _messageFrom(error, 'Şifre sıfırlama isteği gönderilemedi.'),
      );
    }
  }

  Future<AuthUser> signInWithGoogle() async {
    if (ApiConfig.googleServerClientId.isEmpty) {
      throw const AuthException(
        'Google girişi için GOOGLE_SERVER_CLIENT_ID tanımlanmalıdır.',
      );
    }

    final nonce = _createNonce();
    try {
      await _googleSignIn.initialize(
        serverClientId: ApiConfig.googleServerClientId,
        nonce: nonce,
      );
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google kimlik belirteci alınamadı.');
      }
      validateGoogleIdTokenAudience(
        idToken,
        expectedAudience: ApiConfig.googleServerClientId,
      );

      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/google',
        data: {'id_token': idToken, 'nonce': nonce},
        options: Options(extra: const {'skipAuth': true}),
      );
      return _saveTokenResponse(response.data);
    } on GoogleSignInException catch (error) {
      throw AuthException('Google girişi tamamlanamadı: ${error.code.name}');
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error, 'Google girişi yapılamadı.'));
    }
  }

  Future<AuthUser?> silentRefresh() async {
    final bundle = await _apiClient.refreshSession();
    return bundle == null ? null : AuthUser.fromJson(bundle.user);
  }

  Future<void> logout() async {
    String? refreshToken;
    try {
      refreshToken = await _apiClient.readRefreshToken();
      if (refreshToken != null) {
        await _apiClient.dio.post<void>(
          '/api/v1/auth/logout',
          data: {'refresh_token': refreshToken, 'all_devices': false},
          options: Options(extra: const {'skipAuth': true}),
        );
      }
    } on Exception {
      // Sunucu erişilemese bile cihazdaki oturum kapatılır.
    } finally {
      await _apiClient.clearSession();
      await _googleSignIn.signOut();
    }
  }

  Future<void> deleteAccount({String? currentPassword}) async {
    try {
      await _apiClient.dio.delete<void>(
        '/api/v1/auth/me',
        data: {'current_password': currentPassword},
      );
      await _apiClient.clearSession();
      await _googleSignIn.signOut();
    } on DioException catch (error) {
      throw AuthException(_messageFrom(error, 'Hesap silinemedi.'));
    }
  }

  Future<AuthUser> _saveTokenResponse(Map<String, dynamic>? data) async {
    if (data == null) throw const AuthException('Sunucu boş yanıt döndürdü.');
    try {
      final bundle = AuthTokenBundle.fromJson(data);
      await _apiClient.setSession(bundle);
      return AuthUser.fromJson(bundle.user);
    } on FormatException catch (error) {
      throw AuthException(error.message);
    }
  }

  static String _messageFrom(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is Map && detail['message'] is String) {
        return detail['message'] as String;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) {
          final location = first['loc'];
          final field = location is List && location.isNotEmpty
              ? location.last
              : null;
          return field == null
              ? first['msg'] as String
              : '$field: ${first['msg']}';
        }
      }
    }
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return '$fallback (HTTP $statusCode)';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Auth sunucusuna ulaşılamadı: ${ApiConfig.baseUrl}. '
          'Telefon kullanıyorsanız güncel HTTPS tünel adresiyle yeniden '
          'derleyin.';
    }
    return '$fallback ${error.message ?? ''}'.trim();
  }

  static String _createNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

void validateGoogleIdTokenAudience(
  String idToken, {
  required String expectedAudience,
}) {
  try {
    final segments = idToken.split('.');
    if (segments.length != 3) {
      throw const FormatException('JWT üç parçadan oluşmalıdır.');
    }
    final payloadBytes = base64Url.decode(base64Url.normalize(segments[1]));
    final payload = jsonDecode(utf8.decode(payloadBytes));
    if (payload is! Map) {
      throw const FormatException('JWT payload nesnesi bekleniyordu.');
    }
    final audience = payload['aud'];
    final matches =
        audience == expectedAudience ||
        (audience is List && audience.contains(expectedAudience));
    if (!matches) {
      throw const AuthException(
        'Google Client ID eşleşmiyor. Flutter GOOGLE_SERVER_CLIENT_ID ile '
        'backend GOOGLE_OAUTH_CLIENT_IDS aynı Web OAuth Client ID olmalıdır.',
      );
    }
  } on AuthException {
    rethrow;
  } on FormatException {
    throw const AuthException(
      'Google kimlik belirteci okunamadı. OAuth yapılandırmasını kontrol edin.',
    );
  }
}
