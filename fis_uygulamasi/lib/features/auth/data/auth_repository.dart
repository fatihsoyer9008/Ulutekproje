import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/user_facing_error.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../domain/auth_user.dart';

class AuthException implements UserFacingException {
  const AuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String get userMessage => message;

  @override
  String toString() => message;
}

abstract interface class AuthRepositoryBase {
  Future<AuthUser> login({required String email, required String password});

  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  });

  Future<String> verifyEmail(String token);

  Future<String> resendVerification(String email);

  Future<String> forgotPassword(String email);

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser?> silentRefresh();

  Future<AuthUser> updateAvatar(String avatarId);

  Future<void> logout();

  Future<void> deleteAccount({String? currentPassword});
}

class AuthRepository implements AuthRepositoryBase {
  AuthRepository({required ApiClient apiClient, GoogleSignIn? googleSignIn})
    // ignore: prefer_initializing_formals
    : _apiClient = apiClient,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleInitialization;
  String? _googleNonce;

  @override
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
      throw _exceptionFrom(error, 'Giriş yapılamadı.');
    }
  }

  @override
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
        },
        options: Options(extra: const {'skipAuth': true}),
      );
      return 'Adres uygunsa doğrulama bağlantısı e-posta adresinize gönderildi.';
    } on DioException catch (error) {
      throw _exceptionFrom(error, 'Kayıt oluşturulamadı.');
    }
  }

  @override
  Future<String> verifyEmail(String token) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/verify-email',
        data: {'token': token},
        options: Options(extra: const {'skipAuth': true}),
      );
      return 'E-posta adresiniz doğrulandı.';
    } on DioException catch (error) {
      throw _exceptionFrom(error, 'E-posta doğrulanamadı.');
    }
  }

  @override
  Future<String> resendVerification(String email) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/resend-verification',
        data: {'email': email.trim()},
        options: Options(extra: const {'skipAuth': true}),
      );
      return 'Adres uygunsa doğrulama bağlantısı yeniden gönderildi.';
    } on DioException catch (error) {
      throw _exceptionFrom(error, 'Doğrulama e-postası gönderilemedi.');
    }
  }

  @override
  Future<String> forgotPassword(String email) async {
    try {
      await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/forgot-password',
        data: {'email': email.trim()},
        options: Options(extra: const {'skipAuth': true}),
      );
      return 'Adres uygunsa sıfırlama bağlantısı e-posta adresinize gönderildi.';
    } on DioException catch (error) {
      throw _exceptionFrom(error, 'Şifre sıfırlama isteği gönderilemedi.');
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    if (ApiConfig.googleServerClientId.isEmpty) {
      throw const AuthException(
        'Google ile giriş şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.',
      );
    }

    try {
      await _ensureGoogleInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'Google girişi tamamlanamadı. Lütfen tekrar deneyin.',
        );
      }
      validateGoogleIdTokenAudience(
        idToken,
        expectedAudience: ApiConfig.googleServerClientId,
      );

      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/v1/auth/google',
        data: {'id_token': idToken, 'nonce': _googleNonce},
        options: Options(extra: const {'skipAuth': true}),
      );
      return _saveTokenResponse(response.data);
    } on GoogleSignInException catch (error) {
      throw AuthException(googleSignInErrorMessage(error.code));
    } on DioException catch (error) {
      throw _exceptionFrom(error, 'Google girişi yapılamadı.');
    }
  }

  Future<void> _ensureGoogleInitialized() async {
    final existing = _googleInitialization;
    if (existing != null) {
      return existing;
    }

    _googleNonce = _createNonce();
    final initialization = _googleSignIn.initialize(
      serverClientId: ApiConfig.googleServerClientId,
      nonce: _googleNonce,
    );
    _googleInitialization = initialization;
    try {
      await initialization;
    } on Object {
      _googleInitialization = null;
      _googleNonce = null;
      rethrow;
    }
  }

  @override
  Future<AuthUser?> silentRefresh() async {
    final bundle = await _apiClient.refreshSession();
    return bundle == null ? null : AuthUser.fromJson(bundle.user);
  }

  @override
  Future<AuthUser> updateAvatar(String avatarId) async {
    try {
      final response = await _apiClient.dio.patch<Map<String, dynamic>>(
        '/api/v1/auth/me/avatar',
        data: {'avatar_id': avatarId},
      );
      if (response.data == null) {
        throw const AuthException(
          'Avatar güncellenemedi. Lütfen tekrar deneyin.',
        );
      }
      return AuthUser.fromJson(response.data!);
    } on DioException catch (error) {
      throw _exceptionFrom(error, 'Avatar güncellenemedi.');
    }
  }

  @override
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

  @override
  Future<void> deleteAccount({String? currentPassword}) async {
    try {
      await _apiClient.dio.delete<void>(
        '/api/v1/auth/me',
        data: {'current_password': currentPassword},
      );
      await _apiClient.clearSession();
      await _googleSignIn.signOut();
    } on DioException catch (error) {
      throw _exceptionFrom(error, 'Hesap silinemedi.');
    }
  }

  Future<AuthUser> _saveTokenResponse(Map<String, dynamic>? data) async {
    if (data == null) {
      throw const AuthException('Oturum açılamadı. Lütfen tekrar deneyin.');
    }
    try {
      final bundle = AuthTokenBundle.fromJson(data);
      await _apiClient.setSession(bundle);
      return AuthUser.fromJson(bundle.user);
    } on FormatException {
      throw const AuthException('Oturum açılamadı. Lütfen tekrar deneyin.');
    }
  }

  static AuthException _exceptionFrom(DioException error, String fallback) {
    final data = error.response?.data;
    String? code;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map && detail['code'] is String) {
        code = detail['code'] as String;
      }
    }
    final statusCode = error.response?.statusCode;

    if (code == 'email_not_verified') {
      return const AuthException(
        'E-posta adresiniz henüz doğrulanmadı. Doğrulama bağlantısını kontrol edin.',
        code: 'email_not_verified',
      );
    }
    if (code == 'google_account_already_exists') {
      return const AuthException(
        'Bu e-posta adresiyle bir hesap zaten var. Önce e-posta ve şifrenizle giriş yapın.',
        code: 'google_account_already_exists',
      );
    }
    if (statusCode == 429) {
      return const AuthException(
        'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.',
        code: 'rate_limited',
      );
    }
    if (statusCode == 400 || statusCode == 422) {
      return AuthException(
        '$fallback Bilgileri kontrol edip tekrar deneyin.',
        code: code ?? 'invalid_request',
      );
    }
    if (statusCode == 401) {
      return AuthException(
        fallback == 'Giriş yapılamadı.'
            ? 'E-posta adresi veya şifre hatalı.'
            : '$fallback Lütfen yeniden giriş yapıp tekrar deneyin.',
        code: code ?? 'unauthorized',
      );
    }
    if (statusCode == 403) {
      return AuthException(
        '$fallback Bu işlem için hesabınızın doğrulanması gerekiyor.',
        code: code ?? 'forbidden',
      );
    }
    if (statusCode == 409) {
      return AuthException(
        '$fallback Bilgiler başka bir işlemle çakıştı.',
        code: code ?? 'conflict',
      );
    }
    if (statusCode != null) {
      return AuthException(
        '$fallback Servis şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.',
        code: code ?? 'service_unavailable',
      );
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return AuthException(
        'İnternet bağlantısı kurulamadı. Bağlantınızı kontrol edip tekrar deneyin.',
        code: 'connection_failed',
      );
    }
    return AuthException('$fallback Lütfen tekrar deneyin.', code: 'unknown');
  }

  static String _createNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

String googleSignInErrorMessage(GoogleSignInExceptionCode code) {
  switch (code) {
    case GoogleSignInExceptionCode.canceled:
      return 'Google giriş işlemi iptal edildi.';
    case GoogleSignInExceptionCode.clientConfigurationError:
    case GoogleSignInExceptionCode.providerConfigurationError:
      return 'Google ile giriş şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
    case GoogleSignInExceptionCode.interrupted:
      return 'Google giriş işlemi yarıda kesildi. Lütfen tekrar deneyin.';
    case GoogleSignInExceptionCode.uiUnavailable:
      return 'Google hesap seçme ekranı şu anda açılamıyor.';
    default:
      return 'Google girişi tamamlanamadı. Lütfen tekrar deneyin.';
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
      developer.log(
        'Google ID token audience eşleşmedi. GOOGLE_SERVER_CLIENT_ID ile '
        'backend GOOGLE_OAUTH_CLIENT_IDS OAuth Client ID yapılandırmasını '
        'kontrol edin.',
        name: 'app.auth.google_token_validation',
      );
      throw const AuthException(
        'Google girişi doğrulanamadı. Lütfen tekrar deneyin.',
        code: 'google_token_verification_failed',
      );
    }
  } on AuthException {
    rethrow;
  } on FormatException {
    developer.log(
      'google_token_parse_failed',
      name: 'app.auth.google_token_validation',
    );
    throw const AuthException(
      'Google girişi doğrulanamadı. Lütfen tekrar deneyin.',
      code: 'google_token_verification_failed',
    );
  }
}
