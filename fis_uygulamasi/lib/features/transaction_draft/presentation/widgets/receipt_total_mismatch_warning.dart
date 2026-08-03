import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../model/turkish_money.dart';

class ReceiptTotalMismatchWarning extends StatelessWidget {
  const ReceiptTotalMismatchWarning({
    super.key,
    required this.itemsTotalInMinor,
    required this.receiptTotalInMinor,
  });

  final int itemsTotalInMinor;
  final int receiptTotalInMinor;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('receipt_total_mismatch_warning'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.expense.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.expense.withValues(alpha: .45)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.expense),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Ürünlerin toplamı (${itemsTotalInMinor.toTLDisplay}) ile fiş '
            'tutarı (${receiptTotalInMinor.toTLDisplay}) eşleşmiyor!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
