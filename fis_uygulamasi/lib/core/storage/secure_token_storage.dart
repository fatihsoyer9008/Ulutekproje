import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageException implements Exception {
  const TokenStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class TokenStorage {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> deleteRefreshToken();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = 'auth_refresh_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } on PlatformException catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi okunamadı: ${error.message ?? error.code}',
      );
    } on Exception {
      throw const TokenStorageException('Güvenli oturum bilgisi okunamadı.');
    }
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } on PlatformException catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi kaydedilemedi: ${error.message ?? error.code}',
      );
    } on Exception {
      throw const TokenStorageException(
        'Güvenli oturum bilgisi kaydedilemedi.',
      );
    }
  }

  @override
  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
    } on PlatformException catch (error) {
      throw TokenStorageException(
        'Güvenli oturum bilgisi temizlenemedi: ${error.message ?? error.code}',
      );
    } on Exception {
      throw const TokenStorageException(
        'Güvenli oturum bilgisi temizlenemedi.',
      );
    }
  }
}
