import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../domain/group_models.dart';
import '../group_formatters.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    required this.group,
    required this.netAmountInMinor,
    required this.onTap,
    super.key,
  });

  final Group group;
  final int? netAmountInMinor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final net = netAmountInMinor;
    final netColor = net == null || net == 0
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : net > 0
        ? AppColors.income
        : AppColors.expense;
    final description = group.description?.trim();

    return Semantics(
      button: true,
      label: '${group.name}, ${group.memberCount} üye',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('group_card_${group.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.mint,
                      foregroundColor: AppColors.primary,
                      child: Icon(Icons.group_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Info(
                      icon: Icons.people_outline,
                      text: '${group.memberCount} üye',
                    ),
                    _Info(
                      icon: Icons.schedule_outlined,
                      text: 'Son aktivite ${formatGroupDate(group.updatedAt)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  net == null ? 'Bakiye yükleniyor' : formatNetPosition(net),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: netColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
}
