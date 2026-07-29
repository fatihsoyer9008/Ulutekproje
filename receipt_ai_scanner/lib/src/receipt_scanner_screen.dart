import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as image_lib;

import 'receipt_text_normalizer.dart';
import 'camera_failure.dart';

/// Opens the back camera, captures a receipt and extracts its raw text on-device.
class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with WidgetsBindingObserver {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isScanning = false;
  CameraFailure? _cameraFailure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  /// Releases and restores the camera when the app goes into the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _cameraFailure = null;
      });
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCamera',
          'Bu cihazda kullanılabilir kamera bulunamadı.',
        );
      }

      final backCamera = cameras.cast<CameraDescription?>().firstWhere(
        (camera) => camera?.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      )!;

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      final previousController = _cameraController;
      _cameraController = controller;
      await previousController?.dispose();

      setState(() => _isInitializing = false);
    } on CameraException catch (error) {
      _showCameraError(cameraFailureFromException(error));
    } catch (error) {
      _showCameraError(
        CameraFailure(
          type: CameraFailureType.other,
          title: 'Kamera başlatılamadı',
          message: error.toString(),
          canRetry: true,
        ),
      );
    }
  }

  Future<void> _scanReceipt() async {
    final controller = _cameraController;
    if (_isScanning ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _isScanning = true);

    try {
      await _prepareCameraForReceipt(controller);
      final photo = await controller.takePicture();
      final recognizedText = await _recognizeReceiptText(photo);
      final normalizedText = kDebugMode
          ? normalizeAndLogReceiptText(recognizedText.text, logger: debugPrint)
          : normalizeReceiptText(recognizedText.text);

      if (!mounted) return;
      final shouldContinue = await _showRecognizedText(normalizedText);
      if (shouldContinue && mounted) {
        Navigator.of(context).pop(normalizedText);
      }
    } on CameraException catch (error) {
      _showMessage(_cameraErrorMessage(error));
    } catch (error) {
      _showMessage('Fiş okunurken bir hata oluştu: $error');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _prepareCameraForReceipt(CameraController controller) async {
    try {
      await controller.setFocusMode(FocusMode.auto);
      await controller.setFocusPoint(const Offset(.5, .5));
      await controller.setExposureMode(ExposureMode.auto);
      await controller.setExposurePoint(const Offset(.5, .5));
      await controller.setFlashMode(FlashMode.auto);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    } on CameraException {
      // Some devices do not expose every focus/exposure control. Capturing can
      // still continue with the camera's existing defaults.
    }
  }

  Future<RecognizedText> _recognizeReceiptText(XFile photo) async {
    final originalResult = await _textRecognizer.processImage(
      InputImage.fromFilePath(photo.path),
    );
    if (originalResult.text.trim().isNotEmpty) return originalResult;

    final enhancedPath = '${photo.path}.ocr.jpg';
    final enhancedFile = File(enhancedPath);
    try {
      final decoded = image_lib.decodeImage(await photo.readAsBytes());
      if (decoded == null) return originalResult;

      final oriented = image_lib.bakeOrientation(decoded);
      final grayscale = image_lib.grayscale(oriented);
      await enhancedFile.writeAsBytes(
        image_lib.encodeJpg(grayscale, quality: 95),
        flush: true,
      );
      return await _textRecognizer.processImage(
        InputImage.fromFilePath(enhancedPath),
      );
    } on Exception {
      return originalResult;
    } finally {
      if (await enhancedFile.exists()) {
        await enhancedFile.delete();
      }
    }
  }

  Future<bool> _showRecognizedText(String text) async {
    final hasReadableText = text.trim().isNotEmpty;
    final visibleText = hasReadableText
        ? text
        : 'Fiş üzerinde okunabilir metin bulunamadı. Fişi düz bir zemine '
              'yerleştirip iyi ışıkta ve kamerayı sabit tutarak tekrar deneyin.';

    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: FractionallySizedBox(
              heightFactor: .72,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Okunan Fiş Metni',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kapat',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(visibleText),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('continue_with_ocr_button'),
                        onPressed: () =>
                            Navigator.pop(context, hasReadableText),
                        icon: Icon(
                          hasReadableText
                              ? Icons.arrow_forward_rounded
                              : Icons.refresh_rounded,
                        ),
                        label: Text(
                          hasReadableText
                              ? 'Bilgileri Kontrol Et'
                              : 'Tekrar Tara',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
  }

  void _showCameraError(CameraFailure failure) {
    if (!mounted) return;
    setState(() {
      _isInitializing = false;
      _cameraFailure = failure;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _cameraErrorMessage(CameraException error) {
    return cameraFailureFromException(error).message;
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    await controller?.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black.withValues(alpha: .45),
        title: const Text('Fiş Tara'),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            _CameraPreview(controller: controller)
          else
            _CameraStatus(
              isLoading: _isInitializing,
              failure: _cameraFailure,
              onRetry: _initializeCamera,
              onBack: () => Navigator.maybePop(context),
            ),
          if (controller != null && controller.value.isInitialized)
            const _ReceiptGuide(),
          if (_isScanning)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: controller != null && controller.value.isInitialized
          ? Semantics(
              button: true,
              label: 'Fotoğraf çek ve fişi tara',
              child: FloatingActionButton.large(
                heroTag: 'receipt_scan_button',
                onPressed: _isScanning ? null : _scanReceipt,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                child: _isScanning
                    ? const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Icon(Icons.document_scanner_rounded, size: 36),
              ),
            )
          : null,
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
      ),
    ),
  );
}

class _ReceiptGuide extends StatelessWidget {
  const _ReceiptGuide();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 90, 28, 130),
      child: Column(
        children: [
          const Text(
            'Fişi çerçevenin içine yerleştirin',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CameraStatus extends StatelessWidget {
  const _CameraStatus({
    required this.isLoading,
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  final bool isLoading;
  final CameraFailure? failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: isLoading
        ? const CircularProgressIndicator()
        : Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  color: Colors.white,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Column(
                    children: [
                      Text(
                        failure?.title ?? 'Kamera kullanılamıyor',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        failure?.message ?? 'Kamera şu anda kullanılamıyor.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (failure?.canRetry ?? true)
                  FilledButton.icon(
                    key: const Key('retry_camera_permission_button'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      failure?.type == CameraFailureType.permissionDenied
                          ? 'Tekrar İzin İste'
                          : 'Tekrar Dene',
                    ),
                  )
                else
                  OutlinedButton.icon(
                    key: const Key('leave_camera_button'),
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Geri Dön'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
  );
}
