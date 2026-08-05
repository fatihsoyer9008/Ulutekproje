import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReceiptImageUploadStatus {
  idle,
  preparing,
  uploading,
  completed,
  cancelled,
  failed,
}

class ReceiptImageUploadState {
  const ReceiptImageUploadState({
    this.status = ReceiptImageUploadStatus.idle,
    this.progress = 0,
    this.message,
  });

  final ReceiptImageUploadStatus status;
  final double progress;
  final String? message;

  bool get isActive =>
      status == ReceiptImageUploadStatus.preparing ||
      status == ReceiptImageUploadStatus.uploading;

  ReceiptImageUploadState copyWith({
    ReceiptImageUploadStatus? status,
    double? progress,
    String? message,
    bool clearMessage = false,
  }) {
    return ReceiptImageUploadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class ReceiptImageUploadController
    extends StateNotifier<ReceiptImageUploadState> {
  ReceiptImageUploadController() : super(const ReceiptImageUploadState());

  CancelToken? _cancelToken;

  void beginPreparing() {
    _cancelToken?.cancel('Yeni fiş görseli yükleme işlemi başlatıldı.');
    _cancelToken = null;

    state = const ReceiptImageUploadState(
      status: ReceiptImageUploadStatus.preparing,
      progress: 0.05,
      message: 'Görsel yükleme için hazırlanıyor...',
    );
  }

  CancelToken beginUpload() {
    _cancelToken?.cancel('Yeni fiş görseli yükleme işlemi başlatıldı.');
    _cancelToken = CancelToken();

    state = const ReceiptImageUploadState(
      status: ReceiptImageUploadStatus.uploading,
      progress: 0,
      message: 'Görsel sunucuya yükleniyor...',
    );

    return _cancelToken!;
  }

  void updateProgress(int sentBytes, int totalBytes) {
    if (totalBytes <= 0 || !state.isActive) return;

    state = state.copyWith(
      status: ReceiptImageUploadStatus.uploading,
      progress: (sentBytes / totalBytes).clamp(0.0, 1.0),
      message: 'Görsel sunucuya yükleniyor...',
    );
  }

  void complete() {
    _cancelToken = null;
    state = const ReceiptImageUploadState(
      status: ReceiptImageUploadStatus.completed,
      progress: 1,
      message: 'Görsel başarıyla yüklendi.',
    );
  }

  void fail(String message) {
    _cancelToken = null;
    state = ReceiptImageUploadState(
      status: ReceiptImageUploadStatus.failed,
      message: message,
    );
  }

  void cancel() {
    _cancelToken?.cancel('Kullanıcı görsel yükleme işlemini iptal etti.');
    _cancelToken = null;

    state = const ReceiptImageUploadState(
      status: ReceiptImageUploadStatus.cancelled,
      message: 'Görsel yükleme iptal edildi.',
    );
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Görsel yükleme ekranı kapatıldı.');
    super.dispose();
  }
}

final receiptImageUploadProvider =
    StateNotifierProvider<
      ReceiptImageUploadController,
      ReceiptImageUploadState
    >((ref) => ReceiptImageUploadController());
