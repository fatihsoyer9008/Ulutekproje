import 'package:app_main/features/transaction_draft/presentation/controllers/receipt_image_upload_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptImageUploadController', () {
    test('yükleme ilerlemesini izler ve iptal edebilir', () {
      final controller = ReceiptImageUploadController();
      addTearDown(controller.dispose);

      controller.beginPreparing();

      expect(controller.state.status, ReceiptImageUploadStatus.preparing);
      expect(controller.state.progress, 0.05);

      final cancelToken = controller.beginUpload();
      controller.updateProgress(25, 100);

      expect(controller.state.status, ReceiptImageUploadStatus.uploading);
      expect(controller.state.progress, 0.25);
      expect(cancelToken.isCancelled, isFalse);

      controller.cancel();

      expect(controller.state.status, ReceiptImageUploadStatus.cancelled);
      expect(cancelToken.isCancelled, isTrue);
    });

    test('başarılı yüklemeyi yüzde yüz tamamlanmış gösterir', () {
      final controller = ReceiptImageUploadController();
      addTearDown(controller.dispose);

      controller.beginUpload();
      controller.complete();

      expect(controller.state.status, ReceiptImageUploadStatus.completed);
      expect(controller.state.progress, 1);
    });
  });
}
