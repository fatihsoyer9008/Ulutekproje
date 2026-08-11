import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class GroupEmptyState extends StatelessWidget {
  const GroupEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.groups_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: '$title. $message',
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.mint,
                child: Icon(icon, size: 34, color: AppColors.primary),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}
