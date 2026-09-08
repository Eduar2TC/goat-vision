import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:goatvision/core/errors/app_exceptions.dart';
import 'package:goatvision/core/ml/ml_interfaces.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/core/storage/image_storage_service.dart';
import 'package:goatvision/core/utils/app_logger.dart';
import 'package:goatvision/core/vision/morphometric_calculator.dart';
import 'package:goatvision/data/providers/providers.dart';
import 'package:goatvision/domain/entities/animal.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/detection.dart';
import 'package:goatvision/domain/entities/landmark.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';
import 'package:goatvision/features/capture/presentation/widgets/calibration_overlay.dart';
import 'package:goatvision/features/capture/presentation/widgets/detection_overlay.dart';
import 'package:goatvision/features/capture/presentation/widgets/goat_mask_overlay.dart';
import 'package:goatvision/features/capture/presentation/widgets/landmark_overlay.dart';
import 'package:goatvision/features/capture/presentation/widgets/quality_indicator.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  final String? animalId;

  const CaptureScreen({super.key, this.animalId});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  String? _error;

  GoatDetectorService _detector = MockGoatDetector();
  MockGoatSegmenter _segmenter = MockGoatSegmenter();
  MockLandmarkDetector _landmarkDetector = MockLandmarkDetector();
  final MockMarkerDetector _markerDetector = const MockMarkerDetector();

  List<Rect> _boundingBoxes = [];
  List<double> _confidences = [];
  List<Landmark> _landmarks = [];
  List<List<bool>>? _mask;
  int _maskWidth = 0;
  int _maskHeight = 0;
  bool _markerDetected = false;
  double? _markerWidth;
  double? _markerHeight;
  double _cmPerPixel = 0;
  bool _isCapturing = false;

  bool _goatDetected = false;
  bool _bodyComplete = false;
  bool _goodLighting = true;
  bool _validPose = false;
  String? _instruction;
  bool _qualityReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModels();
  }

  Future<void> _loadModels() async {
    try {
      await _detector.load();
      await _segmenter.load();
      await _landmarkDetector.load();
    } catch (e) {
      AppLogger.instance.error('Failed to load models', error: e);
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _error = 'No se encontraron cámaras';
          _isInitializing = false;
        });
        return;
      }

      final back = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(back, ResolutionPreset.high);
      await _controller!.initialize();
      await _controller!.setFocusMode(FocusMode.auto);

      if (!mounted) return;
      setState(() => _isInitializing = false);

      _runMockAnalysis();
    } on CameraException catch (e) {
      AppLogger.instance.error('Camera init error', error: e);
      setState(() {
        _error = 'Error al inicializar la cámara';
        _isInitializing = false;
      });
    }
  }

  void _runMockAnalysis() {
    Future<void>.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted || _controller == null) return;

      final size = _controller!.value.previewSize;
      if (size == null) return;

      final width = size.width.toInt();
      final height = size.height.toInt();

      final detections = await _detector.detect(
        Uint8List(0),
        width,
        height,
      );

      if (!mounted) return;
      if (detections.isEmpty) return;

      final det = detections.first;
      setState(() {
        _boundingBoxes = [
          Rect.fromLTWH(
            det.x / width,
            det.y / height,
            det.width / width,
            det.height / height,
          ),
        ];
        _confidences = [det.confidence];
        _goatDetected = true;
        _bodyComplete = true;
        _validPose = true;
      });

      final mask = await _segmenter.segment(
        Uint8List(0),
        width,
        height,
        det,
      );

      if (!mounted) return;
      setState(() {
        _mask = mask
            .map((row) => row.map((v) => v > 100).toList())
            .toList();
        _maskWidth = width;
        _maskHeight = height;
      });

      final lm = await _landmarkDetector.detectLandmarks(
        Uint8List(0),
        width,
        height,
        det,
      );

      if (!mounted) return;
      setState(() {
        _landmarks = lm.landmarks;
      });

      final marker = await _markerDetector.detectMarker(
        Uint8List(0),
        width,
        height,
      );

      if (!mounted) return;
      setState(() {
        _markerDetected = true;
        _markerWidth = marker.$1 / width;
        _markerHeight = marker.$2 / height;
        _cmPerPixel = 30.0 / marker.$1;
        _qualityReady = true;
        _instruction = 'Lista para capturar';
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.unload();
    _segmenter.unload();
    _landmarkDetector.unload();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || _isCapturing || !_qualityReady) {
      setState(() {
        _instruction = 'Esperando condiciones de captura válidas';
      });
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final xfile = await _controller!.takePicture();

      final imageFile = File(xfile.path);
      final bytes = await imageFile.readAsBytes();

      final size = _controller!.value.previewSize;
      final imageWidth = size?.width.toInt() ?? 1920;
      final imageHeight = size?.height.toInt() ?? 1080;

      final det = Detection(
        x: (_boundingBoxes.isEmpty ? 0.2 : _boundingBoxes.first.left) *
            imageWidth,
        y: (_boundingBoxes.isEmpty ? 0.2 : _boundingBoxes.first.top) *
            imageHeight,
        width: (_boundingBoxes.isEmpty ? 0.5 : _boundingBoxes.first.width) *
            imageWidth,
        height:
            (_boundingBoxes.isEmpty ? 0.5 : _boundingBoxes.first.height) *
                imageHeight,
        confidence: _confidences.isEmpty ? 0.85 : _confidences.first,
      );

      final morphologyResult = _computeMorphometrics();

      final prediction = await _computePrediction(morphologyResult.$1);

      final calibration = Calibration(
        markerWidthPixels: _cmPerPixel > 0 ? 30.0 / _cmPerPixel : 0,
        markerHeightPixels: _cmPerPixel > 0 ? 30.0 / _cmPerPixel : 0,
        realWidthCm: 30.0,
        cmPerPixel: _cmPerPixel,
        confidence: 0.9,
        timestamp: DateTime.now(),
      );

      final imagePath = await _persistCaptureImage(bytes: bytes);

      final state = AnalysisSessionState(
        animalId: widget.animalId ?? '',
        estimatedWeightKg: prediction.estimatedWeightKg,
        lowerWeightKg: prediction.lowerBoundKg,
        upperWeightKg: prediction.upperBoundKg,
        confidence: prediction.confidence,
        modelVersion: prediction.modelVersion,
        datasetVersion: prediction.modelVersion.startsWith('ref-')
            ? 'biodiv-d260710'
            : 'mock-dataset',
        morphometrics: morphologyResult.$1.toMap(),
        timestamp: DateTime.now(),
        imagePath: imagePath,
      );

      ref.read(analysisSessionProvider.notifier).state = state;

      if (mounted) {
        context.go('/analysis');
      }
    } catch (e) {
      AppLogger.instance.error('Capture failed', error: e);
      if (mounted) {
        setState(() {
          _instruction = 'Error al capturar. Intenta de nuevo.';
          _isCapturing = false;
        });
      }
    }
  }

  Future<String?> _persistCaptureImage({required Uint8List bytes}) async {
    try {
      final imageStorage = await ImageStorageService.create();
      final path = await imageStorage.saveCapture(
        bytes: bytes,
        animalId: widget.animalId ?? 'rapid',
      );
      AppLogger.instance.debug('Capture image stored at $path');
      return path;
    } catch (e) {
      AppLogger.instance.error('Failed to persist capture image', error: e);
      return null;
    }
  }

  (MorphometricFeatures, Calibration) _computeMorphometrics() {
    final calibration = Calibration(
      markerWidthPixels: _cmPerPixel > 0 ? 30.0 / _cmPerPixel : 0,
      markerHeightPixels: _cmPerPixel > 0 ? 30.0 / _cmPerPixel : 0,
      realWidthCm: 30.0,
      cmPerPixel: _cmPerPixel,
      confidence: 0.9,
      timestamp: DateTime.now(),
    );

    double bodyAreaPixels = 0;
    if (_mask != null) {
      for (final row in _mask!) {
        for (final px in row) {
          if (px) bodyAreaPixels++;
        }
      }
    }

    final features = MorphometricCalculator.extract(
      _landmarks,
      calibration,
      bodyAreaPixels,
    );

    return (features, calibration);
  }

  Future<double> computeWeightFallback() async {
    final result = _computeMorphometrics();
    final weightResult =
        await ref.read(weightPredictionServiceProvider).run(result.$1);
    return weightResult.prediction.estimatedWeightKg;
  }

  Future<Prediction> _computePrediction(MorphometricFeatures features) async {
    final weightResult =
        await ref.read(weightPredictionServiceProvider).run(features);
    return weightResult.prediction;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: _buildCameraArea(context),
            ),
            _buildBottomControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/dashboard'),
        ),
        const Spacer(),
        const Text(
          'Nueva medición',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildCameraArea(BuildContext context) {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isInitializing = true;
                  _error = null;
                });
                _initCamera();
              },
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(controller),
            CustomPaint(
              painter: DetectionOverlay(
                boundingBoxes: _boundingBoxes,
                confidences: _confidences,
              ),
            ),
            CustomPaint(
              painter: GoatMaskOverlay(
                mask: _mask,
                maskWidth: _maskWidth,
                maskHeight: _maskHeight,
              ),
            ),
            if (_landmarks.isNotEmpty)
              CustomPaint(
                painter: LandmarkOverlay(landmarks: _landmarks),
              ),
            CustomPaint(
              painter: CalibrationOverlay(
                markerDetected: _markerDetected,
                markerWidthPixels: _markerWidth,
                markerHeightPixels: _markerHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    final ready = _qualityReady && !_isCapturing;
    final mode = ref.watch(runModeProvider);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mode == RunMode.mock)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_outlined, color: Colors.amber, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Modo desarrollador · CV simulada',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                ],
              ),
            ),
          QualityIndicator(
            goatDetected: _goatDetected,
            bodyComplete: _bodyComplete,
            markerDetected: _markerDetected,
            goodLighting: _goodLighting,
            validPose: _validPose,
          ),
          const SizedBox(height: 8),
          if (_instruction != null)
            Text(
              _instruction!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_cmPerPixel > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_cmPerPixel.toStringAsFixed(3)} cm/px',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              const SizedBox(width: 12),
              _CaptureButton(
                enabled: ready,
                loading: _isCapturing,
                onPressed: _capture,
              ),
              const SizedBox(width: 12),
              Container(width: 60),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _CaptureButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !loading ? onPressed : null,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? Colors.white : Colors.white30,
            width: 4,
          ),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? Colors.white : Colors.white30,
                  ),
                ),
        ),
      ),
    );
  }
}