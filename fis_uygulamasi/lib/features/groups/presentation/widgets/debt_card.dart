import 'package:flutter/material.dart';

import '../../domain/group_models.dart';
import '../group_formatters.dart';

class DebtCard extends StatelessWidget {
  const DebtCard({
    required this.transfer,
    required this.memberNames,
    required this.currentUserId,
    super.key,
  });

  final DebtTransfer transfer;
  final Map<String, String> memberNames;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final from = memberNames[transfer.fromUserId] ?? 'Bilinmeyen üye';
    final to = memberNames[transfer.toUserId] ?? 'Bilinmeyen üye';
    final title = transfer.fromUserId == currentUserId
        ? '$to kişisine ödeme yap'
        : transfer.toUserId == currentUserId
        ? '$from kişisinden alacağın var'
        : '$from, $to kişisine ödeyecek';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.swap_horiz_rounded),
        title: Text(title),
        trailing: Text(
          formatGroupMoney(transfer.amountInMinor),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
