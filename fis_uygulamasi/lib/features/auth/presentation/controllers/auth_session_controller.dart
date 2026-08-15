import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../../../core/storage/installation_id_provider.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  emailVerificationRequired,
  guest,
  authenticated,
}

class AuthSessionState {
  const AuthSessionState({
    required this.status,
    this.user,
    this.pendingEmail,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
    this.sessionExpired = false,
  });

  const AuthSessionState.initial()
    : this(status: AuthStatus.initializing, isLoading: true);

  final AuthStatus status;
  final AuthUser? user;
  final String? pendingEmail;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;
  final bool sessionExpired;

  AuthSessionState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? pendingEmail,
    bool clearPendingEmail = false,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    bool? sessionExpired,
  }) => AuthSessionState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    pendingEmail: clearPendingEmail
        ? null
        : (pendingEmail ?? this.pendingEmail),
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    sessionExpired: sessionExpired ?? this.sessionExpired,
  );
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ApiConfig.baseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
    installationIdProvider: PersistentInstallationIdProvider(),
  );
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(apiClient: ref.watch(apiClientProvider)),
);

final authSessionControllerProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionState>((ref) {
      final apiClient = ref.watch(apiClientProvider);
      return AuthSessionController(
        ref.watch(authRepositoryProvider),
        unauthorizedEvents: apiClient.unauthorizedEvents,
      );
    });

class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController(this._repository, {Stream<void>? unauthorizedEvents})
    : super(const AuthSessionState.initial()) {
    _unauthorizedSubscription = unauthorizedEvents?.listen((_) {
      _pendingPassword = null;
      state = const AuthSessionState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Oturum süreniz doldu. Lütfen yeniden giriş yapın.',
        sessionExpired: true,
      );
    });
  }

  final AuthRepositoryBase _repository;
  StreamSubscription<void>? _unauthorizedSubscription;
  String? _pendingPassword;

  @override
  void dispose() {
    _unauthorizedSubscription?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    state = const AuthSessionState.initial();
    try {
      final user = await _repository.silentRefresh();
      if (user == null) {
        state = const AuthSessionState(status: AuthStatus.unauthenticated);
      } else if (!user.isEmailVerified) {
        state = AuthSessionState(
          status: AuthStatus.emailVerificationRequired,
          user: user,
          pendingEmail: user.email,
        );
      } else {
        state = AuthSessionState(status: AuthStatus.authenticated, user: user);
      }
    } on Exception {
      state = const AuthSessionState(status: AuthStatus.unauthenticated);
    }
  }

  void continueAsGuest() {
    _pendingPassword = null;
    state = const AuthSessionState(status: AuthStatus.guest);
  }

  void leaveEmailVerification() {
    _pendingPassword = null;
    state = const AuthSessionState(status: AuthStatus.unauthenticated);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final user = await _repository.login(email: email, password: password);
      _pendingPassword = null;
      state = AuthSessionState(status: AuthStatus.authenticated, user: user);
      return true;
    } on AuthException catch (error) {
      if (error.code == 'email_not_verified') {
        _pendingPassword = password;
        state = AuthSessionState(
          status: AuthStatus.emailVerificationRequired,
          pendingEmail: email.trim(),
          errorMessage: error.message,
        );
      } else {
        state = state.copyWith(isLoading: false, errorMessage: error.message);
      }
      return false;
    }
  }

  Future<bool> signInWithGoogle() =>
      _authenticate(_repository.signInWithGoogle);

  Future<bool> _authenticate(Future<AuthUser> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final user = await action();
      state = AuthSessionState(status: AuthStatus.authenticated, user: user);
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    } on Exception {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Beklenmeyen bir hata oluştu.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final message = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      _pendingPassword = password;
      state = AuthSessionState(
        status: AuthStatus.emailVerificationRequired,
        pendingEmail: email.trim(),
        infoMessage: message,
      );
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }

  Future<bool> verifyEmailToken(String token) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final message = await _repository.verifyEmail(token);
      state = state.copyWith(isLoading: false, infoMessage: message);
      return confirmEmailVerification();
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }

  Future<bool> confirmEmailVerification() async {
    final email = state.pendingEmail;
    final password = _pendingPassword;
    if (email == null || password == null) {
      state = const AuthSessionState(
        status: AuthStatus.unauthenticated,
        infoMessage: 'E-posta doğrulandı. Şimdi giriş yapabilirsiniz.',
      );
      return false;
    }

    return login(email, password);
  }

  Future<void> resendVerification() async {
    final email = state.pendingEmail;
    if (email == null) return;

    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final message = await _repository.resendVerification(email);
      state = state.copyWith(isLoading: false, infoMessage: message);
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  Future<bool> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    try {
      final message = await _repository.forgotPassword(email);
      state = state.copyWith(isLoading: false, infoMessage: message);
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _repository.logout();
    _pendingPassword = null;
    state = const AuthSessionState(status: AuthStatus.unauthenticated);
  }

  Future<bool> deleteAccount({String? currentPassword}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteAccount(currentPassword: currentPassword);
      state = const AuthSessionState(status: AuthStatus.unauthenticated);
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
    }
  }
}
