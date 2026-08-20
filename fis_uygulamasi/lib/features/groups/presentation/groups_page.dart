import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../transaction_draft/model/turkish_money.dart';
import '../data/group_api_failure.dart';
import '../data/group_providers.dart';
import '../domain/group_models.dart';

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);
    final currentUserId = ref.watch(authSessionControllerProvider).user?.id;
    final appTheme = Theme.of(context);
    final isDark = appTheme.brightness == Brightness.dark;
    final pageBackground = isDark
        ? const Color(0xFF202123)
        : appTheme.scaffoldBackgroundColor;

    final pageTheme = isDark
        ? ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: pageBackground,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1FB69C),
              brightness: Brightness.dark,
            ),
          )
        : appTheme;
    return Theme(
      data: pageTheme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: pageBackground,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 48,
          leading: IconButton(
            tooltip: 'Geri',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          actions: [
            IconButton(
              tooltip: 'Ara',
              onPressed: () => _showComingSoon(context),
              icon: const Icon(Icons.search_rounded),
            ),
            IconButton(
              tooltip: 'Kişi ekle',
              onPressed: () => _showCreateGroupSheet(context),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _GroupsErrorState(
            message: groupUserMessage(
              error,
              fallbackMessage:
                  'Gruplar yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
            ),
            onRetry: () => ref.invalidate(groupsProvider),
          ),
          data: (response) => _GroupsOverview(
            groups: response.groups,
            currentUserId: currentUserId,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('add_group_expense_button'),
          backgroundColor: const Color(0xFF1FB69C),
          foregroundColor: Colors.white,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 28),
          onPressed: () => _openExpenseEntry(context, groupsAsync.valueOrNull?.groups),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text(
            'Harcama ekle',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        bottomNavigationBar: _GroupsBottomNavigation(
          isDark: isDark,
          lightBackgroundColor: pageBackground,
          onFriendsPressed: () => _showComingSoonMessage(
            context,
            'Arkadaşlar yakında eklenecek.',
          ),
          onActivityPressed: () => _showComingSoonMessage(
            context,
            'Aktivite ekranı yakında eklenecek.',
          ),
          onAccountPressed: () => context.push('/profile'),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Arama yakında eklenecek.')));

  void _showComingSoonMessage(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _openExpenseEntry(BuildContext context, List<Group>? groups) {
    if (groups == null || groups.isEmpty) {
      _showCreateGroupSheet(context);
      return;
    }
    if (groups.length == 1) {
      context.push('/groups/${Uri.encodeComponent(groups.single.id)}');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Masraf eklenecek grubu seçin')),
            for (final group in groups)
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: Text(group.name),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/groups/${Uri.encodeComponent(group.id)}');
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupsBottomNavigation extends StatelessWidget {
  const _GroupsBottomNavigation({
    required this.isDark,
    required this.lightBackgroundColor,
    required this.onFriendsPressed,
    required this.onActivityPressed,
    required this.onAccountPressed,
  });

  final bool isDark;
  final Color lightBackgroundColor;
  final VoidCallback onFriendsPressed;
  final VoidCallback onActivityPressed;
  final VoidCallback onAccountPressed;

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF20C5A7);
    final inactive = isDark ? const Color(0xFFB8C3C9) : const Color(0xFF59645F);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202123) : lightBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF343638) : const Color(0xFFE4E9E6),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _GroupsNavItem(
                  icon: Icons.groups_rounded,
                  label: 'Gruplar',
                  color: active,
                  onTap: () {},
                ),
              ),
              Expanded(
                child: _GroupsNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Arkadaşlar',
                  color: inactive,
                  onTap: onFriendsPressed,
                ),
              ),
              Expanded(
                child: _GroupsNavItem(
                  icon: Icons.insert_chart_outlined_rounded,
                  label: 'Hareketler',
                  color: inactive,
                  onTap: onActivityPressed,
                ),
              ),
              Expanded(
                child: _GroupsNavItem(
                  icon: Icons.account_circle_outlined,
                  label: 'Hesap',
                  color: inactive,
                  onTap: onAccountPressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsNavItem extends StatelessWidget {
  const _GroupsNavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsOverview extends ConsumerWidget {
  const _GroupsOverview({required this.groups, required this.currentUserId});

  final List<Group> groups;
  final String? currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var totalOwedInMinor = 0;
    for (final group in groups) {
      final debt = ref.watch(groupDebtSummaryProvider(group.id)).valueOrNull;
      final currentBalance = debt?.balances.where(
        (balance) => balance.userId == currentUserId,
      );
      if (currentBalance != null && currentBalance.isNotEmpty) {
        totalOwedInMinor += currentBalance.first.netAmountInMinor < 0
            ? -currentBalance.first.netAmountInMinor
            : 0;
      }
    }
    final owed = formatMinorAsTurkishLira(totalOwedInMinor.abs());

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 104),
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    const TextSpan(text: 'Toplam borcunuz '),
                    TextSpan(
                      text: 'TL$owed',
                      style: const TextStyle(color: Color(0xFFFF9C71)),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Filtrele ve sırala',
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          const _GroupsEmptyState()
        else ...[
          for (var index = 0; index < groups.length; index++) ...[
            _GroupCard(
              group: groups[index],
              currentUserId: currentUserId,
              visualIndex: index,
            ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 10),
        ],
        Center(
          child: OutlinedButton.icon(
            key: const Key('create_group_button'),
            onPressed: () => _showCreateGroupSheet(context),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Yeni grup oluştur'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF20C5A7),
              side: const BorderSide(color: Color(0xFF20C5A7)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({
    required this.group,
    required this.currentUserId,
    required this.visualIndex,
  });

  final Group group;
  final String? currentUserId;
  final int visualIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtAsync = ref.watch(groupDebtSummaryProvider(group.id));
    final status = _GroupStatus.fromDebtSummary(debtAsync, currentUserId);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('group_card_${group.id}'),
        onTap: () => context.push('/groups/${Uri.encodeComponent(group.id)}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupVisualTile(
                visualIndex: visualIndex,
                icon: _GroupVisual.fromIndex(visualIndex).icon,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status.primary,
                        key: Key('group_net_status_${group.id}'),
                        style: TextStyle(
                          color: status.color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (status.secondary != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          status.secondary!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _GroupStatus {
  const _GroupStatus(this.primary, this.secondary, this.color);

  final String primary;
  final String? secondary;
  final Color color;

  factory _GroupStatus.fromDebtSummary(
    AsyncValue<DebtSummary> debtAsync,
    String? currentUserId,
  ) {
    if (currentUserId == null) {
      return const _GroupStatus('Harcama yok', null, Color(0xFF69746F));
    }

    return debtAsync.when(
      loading: () => const _GroupStatus('Hesaplanıyor…', null, Color(0xFF69746F)),
      error: (_, _) => const _GroupStatus('Harcama yok', null, Color(0xFF69746F)),
      data: (summary) {
        final currentBalance = summary.balances.where(
          (balance) => balance.userId == currentUserId,
        );
        final netAmountInMinor = currentBalance.isEmpty
            ? 0
            : currentBalance.first.netAmountInMinor;

        if (netAmountInMinor == 0) {
          return const _GroupStatus('Dengede', null, Color(0xFF69746F));
        }

        final amount = 'TL${formatMinorAsTurkishLira(netAmountInMinor.abs())}';
        if (netAmountInMinor > 0) {
          return _GroupStatus(
            '$amount alacağınız var',
            null,
            const Color(0xFF20C5A7),
          );
        }

        String? creditor;
        for (final balance in summary.balances) {
          if (balance.netAmountInMinor > 0) {
            creditor = balance.displayName;
            break;
          }
        }
        return _GroupStatus(
          '$amount borcunuz var',
          creditor == null ? null : '$creditor kişisine $amount borcunuz var',
          const Color(0xFFFF9C71),
        );
      },
    );
  }
}

class _GroupsEmptyState extends StatelessWidget {
  const _GroupsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.group_off_outlined, size: 56, color: Color(0xFF20C5A7)),
          const SizedBox(height: 16),
          Text('Henüz grubunuz yok', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Ortak harcamalarınızı yönetmek için yeni bir grup oluşturun.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _GroupVisual {
  const _GroupVisual(this.icon);

  final IconData icon;

  static _GroupVisual fromIndex(int index) {
    const visuals = [
      _GroupVisual(Icons.home_outlined),
      _GroupVisual(Icons.list_alt_outlined),
      _GroupVisual(Icons.receipt_long_outlined),
    ];
    return visuals[index % visuals.length];
  }
}

class _GroupVisualTile extends StatelessWidget {
  const _GroupVisualTile({required this.visualIndex, required this.icon});

  final int visualIndex;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GroupVisualPainter(visualIndex)),
            Center(child: Icon(icon, color: Colors.white, size: 52)),
          ],
        ),
      ),
    );
  }
}

class _GroupVisualPainter extends CustomPainter {
  const _GroupVisualPainter(this.index);

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final paletteIndex = index % 3;
    final base = switch (paletteIndex) {
      0 => const Color(0xFF0B426A),
      1 => const Color(0xFF0B1D27),
      _ => const Color(0xFF1AB795),
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    if (paletteIndex == 0) {
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height * .38)
          ..lineTo(0, size.height)
          ..close(),
        Paint()..color = const Color(0xFF2C7698),
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .62, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height * .34)
          ..close(),
        Paint()..color = const Color(0xFF082F50),
      );
    } else if (paletteIndex == 1) {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .50, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height * .50)
          ..lineTo(size.width * .50, size.height)
          ..close(),
        Paint()..color = const Color(0xFF2C7594),
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, size.height * .58)
          ..lineTo(size.width, size.height * .58)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        Paint()..color = const Color(0xFF397E9C),
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width, size.height * .58)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width * .50, size.height)
          ..close(),
        Paint()..color = const Color(0xFF71A9C0),
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(size.width * .52, size.height * .22)
          ..lineTo(size.width, size.height * .54)
          ..lineTo(size.width * .30, size.height)
          ..lineTo(0, size.height * .54)
          ..close(),
        Paint()..color = const Color(0xFFE85808),
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width, size.height * .54)
          ..lineTo(size.width, size.height)
          ..lineTo(size.width * .30, size.height)
          ..close(),
        Paint()..color = const Color(0xFF8A4AD1),
      );
    }
  }

  @override
  bool shouldRepaint(_GroupVisualPainter oldDelegate) => oldDelegate.index != index;
}

class _GroupsErrorState extends StatelessWidget {
  const _GroupsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 36),
              const SizedBox(height: 12),
              Text(
                'Gruplar yüklenemedi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                key: const Key('groups_error_message'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('groups_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCreateGroupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CreateGroupSheet(),
  );
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Yeni Grup Oluştur',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Ortak harcamalarınızı bu grup altında yönetin.'),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('group_name_field'),
                controller: _nameController,
                autofocus: true,
                maxLength: 120,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Grup adı',
                  hintText: 'Örn. Ev arkadaşları',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Grup adı boş bırakılamaz.';
                  }

                  if (name.length > 120) {
                    return 'Grup adı en fazla 120 karakter olabilir.';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('create_group_submit_button'),
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Grubu Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(groupRepositoryProvider)
          .createGroup(name: _nameController.text.trim());

      ref.invalidate(groupsProvider);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Grup oluşturuldu.')),
      );
    } on GroupApiException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = groupUserMessage(
          error,
          fallbackMessage: 'Grup oluşturulamadı. Lütfen tekrar deneyin.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = groupUserMessage(
          error,
          fallbackMessage: 'Grup oluşturulamadı. Lütfen tekrar deneyin.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
