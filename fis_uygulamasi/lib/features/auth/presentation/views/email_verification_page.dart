import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_session_controller.dart';
import '../widgets/auth_widgets.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({this.token, super.key});

  final String? token;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState
    extends ConsumerState<EmailVerificationPage> {
  bool _tokenHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleToken());
  }

  Future<void> _handleToken() async {
    final token = widget.token;
    if (_tokenHandled || token == null || token.isEmpty) return;
    _tokenHandled = true;

    final authenticated = await ref
        .read(authSessionControllerProvider.notifier)
        .verifyEmailToken(token);
    if (!mounted) return;
    if (authenticated) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    final email = state.pendingEmail;

    return AuthScaffold(
      title: 'E-postanı doğrula',
      subtitle: email == null
          ? 'E-postanıza gönderilen doğrulama bağlantısını açın.'
          : '$email adresine gönderilen doğrulama bağlantısını açın.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.mark_email_unread_outlined,
            size: 72,
            color: Color(0xFF16856B),
          ),
          const SizedBox(height: 20),
          AuthMessage(error: state.errorMessage, info: state.infoMessage),
          const Text(
            'Bağlantıya tıkladıktan sonra bu ekrana dönüp aşağıdaki '
            'butonla devam edebilirsiniz.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AuthSubmitButton(
            label: 'Doğrulandım / Devam Et',
            isLoading: state.isLoading,
            onPressed: _continue,
          ),
          if (email != null) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(authSessionControllerProvider.notifier)
                        .resendVerification(),
              child: const Text('Doğrulama e-postasını yeniden gönder'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: state.isLoading ? null : () => context.go('/login'),
            child: const Text('Giriş ekranına dön'),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    final state = ref.read(authSessionControllerProvider);
    if (state.status == AuthStatus.unauthenticated) {
      context.go('/login');
      return;
    }

    final authenticated = await ref
        .read(authSessionControllerProvider.notifier)
        .confirmEmailVerification();
    if (!mounted) return;
    if (authenticated) context.go('/home');
  }
}
