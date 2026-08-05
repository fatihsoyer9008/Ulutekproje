import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/receipt_image_upload_controller.dart';

class ReceiptImageUploadStatusPanel extends ConsumerWidget {
  const ReceiptImageUploadStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(receiptImageUploadProvider);

    if (!uploadState.isActive) {
      return const SizedBox.shrink();
    }

    final percentage = (uploadState.progress * 100).round();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          LinearProgressIndicator(
            key: const Key('receipt_image_upload_progress'),
            value: uploadState.progress,
          ),
          const SizedBox(height: 8),
          Text(
            '$percentage% yüklendi',
            key: const Key('receipt_image_upload_progress_text'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
