import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';

enum AuthStatus { initializing, unauthenticated, guest, authenticated }

class AuthSessionState {
  const AuthSessionState({
    required this.status,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  const AuthSessionState.initial()
    : this(status: AuthStatus.initializing, isLoading: true);

  final AuthStatus status;
  final AuthUser? user;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  AuthSessionState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) => AuthSessionState(
    status: status ?? this.status,
    user: clearUser ? null : (user ?? this.user),
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
  );
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ApiConfig.baseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(apiClient: ref.watch(apiClientProvider)),
);

final authSessionControllerProvider =
    StateNotifierProvider<AuthSessionController, AuthSessionState>(
      (ref) => AuthSessionController(ref.watch(authRepositoryProvider)),
    );

class AuthSessionController extends StateNotifier<AuthSessionState> {
  AuthSessionController(this._repository)
    : super(const AuthSessionState.initial());

  final AuthRepository _repository;

  Future<void> initialize() async {
    state = const AuthSessionState.initial();
    try {
      final user = await _repository.silentRefresh();
      state = user == null
          ? const AuthSessionState(status: AuthStatus.unauthenticated)
          : AuthSessionState(status: AuthStatus.authenticated, user: user);
    } on Exception {
      state = const AuthSessionState(status: AuthStatus.unauthenticated);
    }
  }

  void continueAsGuest() {
    state = const AuthSessionState(status: AuthStatus.guest);
  }

  Future<bool> login(String email, String password) async {
    return _authenticate(
      () => _repository.login(email: email, password: password),
    );
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
      state = state.copyWith(isLoading: false, infoMessage: message);
      return true;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      return false;
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
