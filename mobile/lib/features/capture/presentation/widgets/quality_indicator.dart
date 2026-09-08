import 'package:flutter/material.dart';
import 'package:goatvision/core/constants/app_colors.dart';

class QualityIndicator extends StatelessWidget {
  final bool goatDetected;
  final bool bodyComplete;
  final bool markerDetected;
  final bool goodLighting;
  final bool validPose;

  const QualityIndicator({
    super.key,
    required this.goatDetected,
    required this.bodyComplete,
    required this.markerDetected,
    required this.goodLighting,
    required this.validPose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(ok: goatDetected, label: 'Cabra detectada'),
          _Row(ok: bodyComplete, label: 'Cuerpo completo'),
          _Row(ok: markerDetected, label: 'Marcador detectado'),
          _Row(ok: goodLighting, label: 'Buena iluminación'),
          _Row(ok: validPose, label: 'Pose válida'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final bool ok;
  final String label;

  const _Row({required this.ok, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color: ok ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}