import 'package:flutter/material.dart';

enum GroupsBottomTab { groups, friends, activity, account }

/// Shared bottom navigation bar for the Groups/Friends/Activity tabs so the
/// four screens stay pixel-identical instead of drifting apart over time.
class GroupsBottomNavigation extends StatelessWidget {
  const GroupsBottomNavigation({
    super.key,
    required this.activeTab,
    required this.isDark,
    required this.lightBackgroundColor,
    required this.onGroupsPressed,
    required this.onFriendsPressed,
    required this.onActivityPressed,
    required this.onAccountPressed,
  });

  final GroupsBottomTab activeTab;
  final bool isDark;
  final Color lightBackgroundColor;
  final VoidCallback onGroupsPressed;
  final VoidCallback onFriendsPressed;
  final VoidCallback onActivityPressed;
  final VoidCallback onAccountPressed;

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF20C5A7);
    final inactive = isDark ? const Color(0xFFB8C3C9) : const Color(0xFF59645F);

    Color colorFor(GroupsBottomTab tab) => tab == activeTab ? active : inactive;

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
                  color: colorFor(GroupsBottomTab.groups),
                  onTap: activeTab == GroupsBottomTab.groups
                      ? () {}
                      : onGroupsPressed,
                ),
              ),
              Expanded(
                child: _GroupsNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Arkadaşlar',
                  color: colorFor(GroupsBottomTab.friends),
                  onTap: activeTab == GroupsBottomTab.friends
                      ? () {}
                      : onFriendsPressed,
                ),
              ),
              Expanded(
                child: _GroupsNavItem(
                  icon: Icons.insert_chart_outlined_rounded,
                  label: 'Hareketler',
                  color: colorFor(GroupsBottomTab.activity),
                  onTap: activeTab == GroupsBottomTab.activity
                      ? () {}
                      : onActivityPressed,
                ),
              ),
              Expanded(
                child: _GroupsNavItem(
                  icon: Icons.account_circle_outlined,
                  label: 'Hesap',
                  color: colorFor(GroupsBottomTab.account),
                  onTap: activeTab == GroupsBottomTab.account
                      ? () {}
                      : onAccountPressed,
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
