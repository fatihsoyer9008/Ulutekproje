import 'package:camera/camera.dart';

enum CameraFailureType {
  permissionDenied,
  permissionBlocked,
  restricted,
  other,
}

class CameraFailure {
  const CameraFailure({
    required this.type,
    required this.title,
    required this.message,
    required this.canRetry,
  });

  final CameraFailureType type;
  final String title;
  final String message;
  final bool canRetry;
}

CameraFailure cameraFailureFromException(CameraException error) {
  return switch (error.code) {
    'CameraAccessDenied' => const CameraFailure(
      type: CameraFailureType.permissionDenied,
      title: 'Kamera izni gerekli',
      message: 'Fiş tarayabilmek için kamera erişimine izin vermelisiniz.',
      canRetry: true,
    ),
    'CameraAccessDeniedWithoutPrompt' => const CameraFailure(
      type: CameraFailureType.permissionBlocked,
      title: 'Kamera izni kapalı',
      message:
          'Kamera izni kalıcı olarak kapatılmış. Cihaz ayarlarından '
          'bu uygulama için kamera erişimini açın.',
      canRetry: false,
    ),
    'CameraAccessRestricted' => const CameraFailure(
      type: CameraFailureType.restricted,
      title: 'Kamera erişimi kısıtlı',
      message:
          'Kamera erişimi cihaz ayarları veya ebeveyn denetimleri '
          'tarafından kısıtlanmış.',
      canRetry: false,
    ),
    _ => CameraFailure(
      type: CameraFailureType.other,
      title: 'Kamera kullanılamıyor',
      message: error.description ?? 'Kamera kullanılırken bir hata oluştu.',
      canRetry: true,
    ),
  };
}
