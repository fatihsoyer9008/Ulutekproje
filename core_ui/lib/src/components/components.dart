import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: isDark
                ? const []
                : const [
                    BoxShadow(
                      color: Color(0x0D13251F),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    required this.title,
    this.onMenuPressed,
    this.onNotificationsPressed,
    this.notificationCount = 0,
    super.key,
  });
  final String title;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onNotificationsPressed;
  final int notificationCount;
  @override
  Size get preferredSize => const Size.fromHeight(70);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 70,
    leadingWidth: 68,
    leading: Padding(
      padding: const EdgeInsets.only(left: 16),
      child: IconButton.filledTonal(
        key: const Key('app_menu_button'),
        tooltip: 'Menü',
        onPressed: onMenuPressed,
        icon: const Icon(Icons.menu_rounded),
      ),
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleLarge),
    actions: [
      Badge.count(
        count: notificationCount,
        isLabelVisible: notificationCount > 0,
        backgroundColor: AppColors.expense,
        child: IconButton.filledTonal(
          key: const Key('notifications_button'),
          tooltip: 'Bildirimler',
          onPressed: onNotificationsPressed,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ),
      const SizedBox(width: 16),
    ],
  );
}

class FinanceBottomNavBar extends StatelessWidget {
  const FinanceBottomNavBar({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: currentIndex,
    onDestinationSelected: onDestinationSelected,
    height: 74,
    labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Ana Menü',
      ),
      NavigationDestination(
        icon: Icon(Icons.insights_outlined),
        selectedIcon: Icon(Icons.insights_rounded),
        label: 'İstatistik',
      ),
      NavigationDestination(
        icon: Icon(Icons.savings_outlined),
        selectedIcon: Icon(Icons.savings_rounded),
        label: 'Kumbara',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Takvim',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: 'Hareketler',
      ),
    ],
  );
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = true,
    super.key,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(58),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: isPrimary ? scheme.primary : scheme.secondaryContainer,
      foregroundColor: isPrimary
          ? scheme.onPrimary
          : scheme.onSecondaryContainer,
    );
    return isPrimary
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          )
        : FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    required this.title,
    required this.body,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.onAiAssistantPressed,
    this.drawer,
    this.notificationCount = 0,
    this.onNotificationsPressed,
    super.key,
  });
  final String title;
  final Widget body;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onAiAssistantPressed;
  final Widget? drawer;
  final int notificationCount;
  final VoidCallback? onNotificationsPressed;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffoldKey,
    drawer: widget.drawer,
    appBar: CustomAppBar(
      title: widget.title,
      onMenuPressed: widget.drawer == null
          ? null
          : () => _scaffoldKey.currentState?.openDrawer(),
      onNotificationsPressed: widget.onNotificationsPressed,
      notificationCount: widget.notificationCount,
    ),
    body: SafeArea(top: false, child: widget.body),
    bottomNavigationBar: FinanceBottomNavBar(
      currentIndex: widget.currentIndex,
      onDestinationSelected: widget.onDestinationSelected,
    ),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'ai',
      onPressed:
          widget.onAiAssistantPressed ??
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kişisel Asistanın yakında sizinle.')),
          ),
      icon: const Icon(Icons.auto_awesome_rounded),
      label: const Text('Kişisel Asistanın'),
    ),
  );
}
