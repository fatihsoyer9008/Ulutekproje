import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../data/pending_receipts_gateway.dart';
import '../domain/pending_receipt.dart';

final pendingReceiptsGatewayProvider = Provider<PendingReceiptsGateway>(
  (ref) => DioPendingReceiptsGateway(apiClient: ref.watch(apiClientProvider)),
);

final pendingReceiptsControllerProvider =
    AsyncNotifierProvider<PendingReceiptsController, List<PendingReceipt>>(
      PendingReceiptsController.new,
    );

/// Dashboard rozeti için ayrı bir bağımlılık zinciri gerektirmeden
/// bekleyen fiş sayısını okumayı kolaylaştırır.
final pendingReceiptCountProvider = Provider<int>((ref) {
  final receipts = ref.watch(pendingReceiptsControllerProvider);
  return receipts.valueOrNull?.length ?? 0;
});

class PendingReceiptsController extends AsyncNotifier<List<PendingReceipt>> {
  @override
  Future<List<PendingReceipt>> build() {
    return ref.read(pendingReceiptsGatewayProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<PendingReceipt>>().copyWithPrevious(
      state,
    );
    state = await AsyncValue.guard(
      () => ref.read(pendingReceiptsGatewayProvider).list(),
    );
  }

  Future<PendingReceipt> approve(
    String id, {
    String? merchantName,
    int? totalAmountInMinor,
    String? currency,
    DateTime? receiptDate,
    String? category,
  }) async {
    final approved = await ref
        .read(pendingReceiptsGatewayProvider)
        .approve(
          id,
          merchantName: merchantName,
          totalAmountInMinor: totalAmountInMinor,
          currency: currency,
          receiptDate: receiptDate,
          category: category,
        );
    _removeLocally(id);
    return approved;
  }

  Future<void> reject(String id) async {
    await ref.read(pendingReceiptsGatewayProvider).reject(id);
    _removeLocally(id);
  }

  void _removeLocally(String id) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.where((item) => item.id != id).toList());
  }
}
