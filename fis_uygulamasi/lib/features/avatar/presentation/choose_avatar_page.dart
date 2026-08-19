import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../domain/avatar_catalog.dart';
import 'widgets/person_avatar_painter.dart';

class ChooseAvatarPage extends ConsumerStatefulWidget {
  const ChooseAvatarPage({super.key});

  @override
  ConsumerState<ChooseAvatarPage> createState() => _ChooseAvatarPageState();
}

class _ChooseAvatarPageState extends ConsumerState<ChooseAvatarPage> {
  String? _selectedId;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    if (!_initialized) {
      _selectedId = state.user?.avatarId;
      _initialized = true;
    }
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatarını seç'),
        automaticallyImplyLeading: canPop,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sana en uygun karakteri seç',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bu avatar profilinde ve grup arkadaşlarına görünür.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: AppColors.expense),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: GridView.builder(
                  key: const Key('avatar_options_grid'),
                  itemCount: avatarCatalog.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final option = avatarCatalog[index];
                    final selected = option.id == _selectedId;
                    return _AvatarOptionTile(
                      option: option,
                      selected: selected,
                      onTap: () => setState(() => _selectedId = option.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('confirm_avatar_selection'),
                  onPressed: _selectedId == null || state.isLoading
                      ? null
                      : _confirm,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Devam Et'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final selected = _selectedId;
    if (selected == null) return;
    final success = await ref
        .read(authSessionControllerProvider.notifier)
        .updateAvatar(selected);
    if (!success || !mounted) return;
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }
}

class _AvatarOptionTile extends StatelessWidget {
  const _AvatarOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AvatarOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('avatar_option_${option.id}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: option.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 3,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: CustomPaint(
        painter: PersonAvatarPainter(option.spec),
        child: const SizedBox.expand(),
      ),
    ),
  );
}
