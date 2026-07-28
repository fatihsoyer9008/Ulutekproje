import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_text_normalizer.dart';
import 'receipt_confidence_warning.dart';

/// Opens the back camera, captures a receipt and extracts its raw text on-device.
class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({
    this.confidenceScore,
    this.confidenceThreshold = ReceiptLowConfidenceWarning.defaultThreshold,
    super.key,
  }) : assert(confidenceScore == null ||
            (confidenceScore! >= 0 && confidenceScore! <= 1)),
       assert(confidenceThreshold >= 0 && confidenceThreshold <= 1);

  /// Confidence produced by the receipt parser, expressed from 0 to 1.
  ///
  /// This is nullable because the current OCR-only flow does not yet produce a
  /// parser score. Pass the score once the parsing pipeline is available.
  final double? confidenceScore;
  final double confidenceThreshold;

  @override
  State<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with WidgetsBindingObserver {
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  CameraController? _cameraController;
  bool _isInitializing = true;
  bool _isScanning = false;
  String? _cameraError;

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
        _cameraError = null;
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
      _showCameraError(_cameraErrorMessage(error));
    } catch (error) {
      _showCameraError('Kamera başlatılamadı: $error');
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
      final photo = await controller.takePicture();
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final normalizedText = kDebugMode
          ? normalizeAndLogReceiptText(
              recognizedText.text,
              logger: debugPrint,
            )
          : normalizeReceiptText(recognizedText.text);

      if (!mounted) return;
      await _showRecognizedText(
        normalizedText,
        confidenceScore: widget.confidenceScore,
      );
    } on CameraException catch (error) {
      _showMessage(_cameraErrorMessage(error));
    } catch (error) {
      _showMessage('Fiş okunurken bir hata oluştu: $error');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _showRecognizedText(
    String text, {
    required double? confidenceScore,
  }) async {
    final visibleText =
        text.trim().isEmpty ? 'Fiş üzerinde okunabilir metin bulunamadı.' : text;

    await showModalBottomSheet<void>(
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
                if (confidenceScore != null) ...[
                  ReceiptLowConfidenceWarning(
                    confidenceScore: confidenceScore,
                    threshold: widget.confidenceThreshold,
                  ),
                  if (confidenceScore < widget.confidenceThreshold)
                    const SizedBox(height: 16),
                ],
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(visibleText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCameraError(String message) {
    if (!mounted) return;
    setState(() {
      _isInitializing = false;
      _cameraError = message;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _cameraErrorMessage(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' =>
        'Kamera izni verilmedi. Lütfen cihaz ayarlarından kamera erişimini açın.',
      _ => error.description ?? 'Kamera kullanılırken bir hata oluştu.',
    };
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
              error: _cameraError,
              onRetry: _initializeCamera,
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
      floatingActionButton:
          controller != null && controller.value.isInitialized
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
    required this.error,
    required this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

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
                    Text(
                      error ?? 'Kamera kullanılamıyor.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
      );
}
