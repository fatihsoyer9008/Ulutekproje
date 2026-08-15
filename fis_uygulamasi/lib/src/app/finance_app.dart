import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart' hide SyncState;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_mode_provider.dart';
import '../../features/ai_assistant/domain/ai_assistant_message_stream.dart';
import '../../features/ai_assistant/data/ai_assistant_client.dart';
import '../../features/auth/presentation/controllers/auth_session_controller.dart';
import '../../features/backup/data/transaction_json_import_service.dart';
import '../../features/groups/data/group_providers.dart';
import '../../features/groups/domain/group_models.dart';
import '../../features/notifications/notification_navigation_controller.dart';
import '../../features/sync/application/sync_coordinator.dart';
import '../../features/sync/domain/sync_state.dart';
import '../screens/expense_screen.dart';
import 'app_router.dart';
import 'finance_home.dart';

typedef InitialDeepLinkLoader = Future<Uri?> Function();

class FinanceApp extends ConsumerStatefulWidget {
  const FinanceApp({
    super.key,
    this.enableAuth = false,
    this.enableStartupSync = false,
    this.enableDatabaseFeatures = false,
    this.notificationNavigationController,
    this.transactionStream = const Stream<List<TransactionEntity>>.empty(),
    this.transactionStreamFactory,
    this.saveTransaction,
    this.scanReceipt,
    this.parseReceipt,
    this.transactionImportService,
    this.aiAssistantMessageStream,
    this.profileAiAssistantClient,
    this.deepLinkStream,
    this.initialDeepLinkLoader,
  });

  final bool enableAuth;
  final bool enableStartupSync;
  final bool enableDatabaseFeatures;
  final NotificationNavigationController? notificationNavigationController;
  final Stream<List<TransactionEntity>> transactionStream;
  final Stream<List<TransactionEntity>> Function()? transactionStreamFactory;
  final Future<void> Function(TransactionEntity transaction)? saveTransaction;
  final ReceiptScanLauncher? scanReceipt;
  final ReceiptParseHandler? parseReceipt;
  final TransactionJsonImportService? transactionImportService;
  final AiAssistantMessageStream? aiAssistantMessageStream;
  final AiAssistantAccessClient? profileAiAssistantClient;
  final Stream<Uri>? deepLinkStream;
  final InitialDeepLinkLoader? initialDeepLinkLoader;

  @override
  ConsumerState<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends ConsumerState<FinanceApp> {
  GoRouter? _router;
  ProviderSubscription<AuthSessionState>? _authSubscription;
  StreamSubscription<Uri>? _deepLinkSubscription;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  String? _pendingGroupInvitationToken;
  final Set<String> _handledDeepLinkKeys = <String>{};
  bool _acceptingGroupInvitation = false;
  bool _invitationLoginMessageShown = false;

  @override
  void initState() {
    super.initState();

    if (widget.enableAuth || widget.enableStartupSync) {
      _authSubscription = ref.listenManual(authSessionControllerProvider, (
        previous,
        next,
      ) {
        if (widget.enableStartupSync &&
            next.status == AuthStatus.authenticated &&
            previous?.status != AuthStatus.authenticated) {
          unawaited(
            ref.read(syncCoordinatorProvider.notifier).syncPendingTasks(),
          );
        }
        if (widget.enableAuth && previous?.status != next.status) {
          _router?.refresh();
          _continuePendingInvitation(next.status);
        }
      }, fireImmediately: true);
    }

    if (widget.enableAuth) {
      _router = createAppRouter(
        ref: ref,
        enableDatabaseFeatures: widget.enableDatabaseFeatures,
        transactionStreamFactory:
            widget.transactionStreamFactory ?? () => widget.transactionStream,
        saveTransaction: widget.saveTransaction,
        scanReceipt: widget.scanReceipt,
        parseReceipt: widget.parseReceipt,
        transactionImportService: widget.transactionImportService,
        aiAssistantMessageStream: widget.aiAssistantMessageStream,
        profileAiAssistantClient: widget.profileAiAssistantClient,
      );

      final router = _router;

      if (router != null) {
        widget.notificationNavigationController?.attachNavigator((location) {
          unawaited(router.push<void>(location));
        });

        final appLinks = AppLinks();
        final linkStream = widget.deepLinkStream ?? appLinks.uriLinkStream;
        _deepLinkSubscription = linkStream.listen(
          (uri) => unawaited(_handleDeepLinkOnce(uri)),
          onError: (Object _, StackTrace _) {
            _showMessage('Bağlantı açılamadı. Lütfen tekrar deneyin.');
          },
        );
        unawaited(
          _loadInitialDeepLink(
            widget.initialDeepLinkLoader ?? appLinks.getInitialLink,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.close();
    final deepLinkSubscription = _deepLinkSubscription;
    if (deepLinkSubscription != null) {
      unawaited(deepLinkSubscription.cancel());
    }
    widget.notificationNavigationController?.detachNavigator();
    _router?.dispose();
    super.dispose();
  }

  Future<void> _loadInitialDeepLink(InitialDeepLinkLoader loader) async {
    try {
      final uri = await loader();
      if (uri != null) await _handleDeepLinkOnce(uri);
    } on Exception {
      // Stream dinleyicisi çalışmaya devam eder; token veya URI loglanmaz.
    }
  }

  Future<void> _handleDeepLinkOnce(Uri uri) async {
    final key = uri.toString();
    if (!_handledDeepLinkKeys.add(key)) return;
    await _handleDeepLink(uri);
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'fiskon' ||
        uri.host.toLowerCase() != 'auth') {
      return;
    }

    final token = uri.queryParameters['token']?.trim();
    if (token == null || token.isEmpty) return;

    if (uri.path == '/verify-email') {
      _openEmailVerification(token);
      return;
    }
    if (uri.path != '/group-invitation') return;

    _pendingGroupInvitationToken = token;
    _invitationLoginMessageShown = false;
    _continuePendingInvitation(ref.read(authSessionControllerProvider).status);
  }

  void _openEmailVerification(String token) {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router?.go(
        Uri(
          path: '/verify-email',
          queryParameters: {'token': token},
        ).toString(),
      );
    });
  }

  void _continuePendingInvitation(AuthStatus status) {
    if (_pendingGroupInvitationToken == null) return;

    switch (status) {
      case AuthStatus.authenticated:
        unawaited(_acceptPendingGroupInvitation());
      case AuthStatus.unauthenticated || AuthStatus.guest:
        _openInvitationLogin();
      case AuthStatus.emailVerificationRequired:
        _showInvitationLoginMessage(
          'Daveti kabul etmek için e-posta adresinizi doğrulayın.',
        );
      case AuthStatus.initializing:
        break;
    }
  }

  void _openInvitationLogin() {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingGroupInvitationToken == null) return;
      _router?.go('/login');
      _showInvitationLoginMessage(
        'Grup davetini kabul etmek için giriş yapın.',
      );
    });
  }

  void _showInvitationLoginMessage(String message) {
    if (_invitationLoginMessageShown) return;
    _invitationLoginMessageShown = true;
    _showMessage(message);
  }

  Future<void> _acceptPendingGroupInvitation() async {
    if (_acceptingGroupInvitation) return;
    final token = _pendingGroupInvitationToken;
    if (token == null) return;

    _acceptingGroupInvitation = true;
    try {
      final member = await ref
          .read(groupRepositoryProvider)
          .acceptInvitation(token);
      if (_pendingGroupInvitationToken == token) {
        _pendingGroupInvitationToken = null;
      }
      ref.invalidate(groupsProvider);
      ref.invalidate(groupDetailProvider(member.groupId));
      ref.invalidate(groupDebtSummaryProvider(member.groupId));
      ref.invalidate(groupSettlementsProvider(member.groupId));
      _navigateAfterInvitation(
        '/groups/${member.groupId}',
        'Grup daveti kabul edildi.',
      );
    } catch (error) {
      if (_pendingGroupInvitationToken == token) {
        _pendingGroupInvitationToken = null;
      }
      _showMessage(_invitationErrorMessage(error));
    } finally {
      _acceptingGroupInvitation = false;
      if (_pendingGroupInvitationToken != null &&
          ref.read(authSessionControllerProvider).status ==
              AuthStatus.authenticated) {
        unawaited(_acceptPendingGroupInvitation());
      }
    }
  }

  String _invitationErrorMessage(Object error) {
    if (error is GroupApiException) {
      return switch (error.error.detail.code) {
        'invitation_expired_or_used' =>
          'Bu davetin süresi dolmuş veya davet daha önce kullanılmış.',
        'invitation_email_mismatch' =>
          'Bu davet farklı bir e-posta hesabına ait.',
        _ => error.error.detail.message,
      };
    }
    return 'Grup daveti kabul edilemedi. Lütfen tekrar deneyin.';
  }

  void _navigateAfterInvitation(String location, String message) {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router?.go(location);
      _showMessage(message);
    });
  }

  void _showMessage(String message) {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = _scaffoldMessengerKey.currentState;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = widget.enableStartupSync
        ? ref.watch(syncCoordinatorProvider)
        : const SyncState();
    final themeMode = widget.enableAuth
        ? ref.watch(appThemeModeProvider)
        : ThemeMode.light;
    if (widget.enableAuth) {
      final authStatus = ref.watch(authSessionControllerProvider).status;

      final navigationReady =
          authStatus == AuthStatus.authenticated ||
          authStatus == AuthStatus.guest;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        widget.notificationNavigationController?.setNavigationReady(
          navigationReady,
        );
      });
    }

    final router = _router;

    if (widget.enableAuth && router != null) {
      return MaterialApp.router(
        title: 'Cüzdanım',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        themeAnimationDuration: Duration.zero,
        routerConfig: router,
        builder: widget.enableStartupSync
            ? (context, child) => _SyncStatusOverlay(
                state: syncState,
                child: child ?? const SizedBox.shrink(),
              )
            : null,
      );
    }

    return MaterialApp(
      title: 'Cüzdanım',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      builder: widget.enableStartupSync
          ? (context, child) => _SyncStatusOverlay(
              state: syncState,
              child: child ?? const SizedBox.shrink(),
            )
          : null,
      home: StreamBuilder<List<TransactionEntity>>(
        stream: widget.transactionStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('İşlemler yüklenemedi.')),
            );
          }

          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return FinanceHome(
            transactions: snapshot.requireData,
            saveTransaction: widget.saveTransaction,
            scanReceipt: widget.scanReceipt,
            parseReceipt: widget.parseReceipt,
            aiAssistantMessageStream: widget.aiAssistantMessageStream,
          );
        },
      ),
    );
  }
}

class _SyncStatusOverlay extends StatelessWidget {
  const _SyncStatusOverlay({required this.state, required this.child});

  final SyncState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (state.status == SyncStatus.syncing)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(value: state.progress),
          ),
        if (state.status == SyncStatus.error ||
            state.status == SyncStatus.conflict)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.errorMessage ?? 'Senkronizasyon tamamlanamadı.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
