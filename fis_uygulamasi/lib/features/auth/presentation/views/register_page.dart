import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_session_controller.dart';
import '../widgets/auth_widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  double _strength = 0;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    return AuthScaffold(
      title: 'Hesabını oluştur',
      subtitle: 'Verilerin yalnızca senin hesabınla ilişkilendirilsin.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthMessage(error: state.errorMessage, info: state.infoMessage),
            TextFormField(
              controller: _firstName,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.givenName],
              decoration: const InputDecoration(
                labelText: 'Ad (isteğe bağlı)',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _lastName,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.familyName],
              decoration: const InputDecoration(
                labelText: 'Soyad (isteğe bağlı)',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _registerEmailValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              onChanged: (value) => setState(() => _strength = _score(value)),
              decoration: const InputDecoration(
                labelText: 'Şifre',
                helperText:
                    'En az 12 karakter; büyük/küçük harf ve rakam kullanın.',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.length < 12) {
                  return 'Şifre en az 12 karakter olmalıdır.';
                }
                if (_score(value) < .75) {
                  return 'Daha güçlü bir şifre seçin.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _strength,
              minHeight: 7,
              borderRadius: BorderRadius.circular(10),
              color: _strength >= .75 ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 22),
            AuthSubmitButton(
              label: 'Kayıt Ol',
              isLoading: state.isLoading,
              onPressed: _register,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Zaten hesabın var mı? Giriş yap'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final displayName = [
      _firstName.text.trim(),
      _lastName.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final success = await ref
        .read(authSessionControllerProvider.notifier)
        .register(
          email: _email.text,
          password: _password.text,
          displayName: displayName,
        );
    if (success && mounted) context.go('/verify-email?from=register');
  }

  static double _score(String value) {
    var score = 0;
    if (value.length >= 12) score++;
    if (RegExp('[a-z]').hasMatch(value)) score++;
    if (RegExp('[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'\d').hasMatch(value)) score++;
    return score / 4;
  }
}

String? _registerEmailValidator(String? value) {
  final email = value?.trim() ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Geçerli bir e-posta adresi girin.';
  }
  return null;
}
