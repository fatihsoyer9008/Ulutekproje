import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_session_controller.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    return AuthScaffold(
      title: 'Şifreni yenile',
      subtitle: 'Uygunsa e-posta adresine güvenli bir bağlantı göndereceğiz.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthMessage(error: state.errorMessage, info: state.infoMessage),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _forgotPasswordEmailValidator,
            ),
            const SizedBox(height: 20),
            AuthSubmitButton(
              label: 'Sıfırlama Bağlantısı Gönder',
              isLoading: state.isLoading,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  ref
                      .read(authSessionControllerProvider.notifier)
                      .forgotPassword(_email.text);
                }
              },
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

String? _forgotPasswordEmailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Geçerli bir e-posta adresi girin.';
  }
  return null;
}
