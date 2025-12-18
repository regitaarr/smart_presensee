import 'package:flutter/material.dart';

/// Widget sederhana untuk menampilkan confidence score dengan warna
class ConfidenceScoreIndicator extends StatelessWidget {
  final double? confidenceScore; // 0-100
  final bool isVisible;
  final String? studentName;

  const ConfidenceScoreIndicator({
    super.key,
    this.confidenceScore,
    this.isVisible = false,
    this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || confidenceScore == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _getConfidenceColor(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getConfidenceColor().withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${confidenceScore!.toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getConfidenceColor() {
    if (confidenceScore! >= 95) {
      return const Color(0xFF4CAF50); // Green - High confidence
    } else if (confidenceScore! >= 85) {
      return const Color(0xFFFFC107); // Amber - Medium confidence
    } else {
      return const Color(0xFFF44336); // Red - Low confidence
    }
  }
}

/// Compact version untuk status bar
class CompactConfidenceIndicator extends StatelessWidget {
  final double? confidenceScore;
  final bool isVisible;

  const CompactConfidenceIndicator({
    super.key,
    this.confidenceScore,
    this.isVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || confidenceScore == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getConfidenceColor().withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            color: _getConfidenceColor(),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '${confidenceScore!.toStringAsFixed(1)}%',
            style: TextStyle(
              color: _getConfidenceColor(),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor() {
    if (confidenceScore! >= 95) {
      return const Color(0xFF4CAF50);
    } else if (confidenceScore! >= 85) {
      return const Color(0xFFFFC107);
    } else {
      return const Color(0xFFF44336);
    }
  }
}

/// Widget animasi saat processing dengan confidence
class ConfidenceProcessingIndicator extends StatefulWidget {
  final bool isProcessing;
  final double? currentConfidence;

  const ConfidenceProcessingIndicator({
    super.key,
    required this.isProcessing,
    this.currentConfidence,
  });

  @override
  State<ConfidenceProcessingIndicator> createState() =>
      _ConfidenceProcessingIndicatorState();
}

class _ConfidenceProcessingIndicatorState
    extends State<ConfidenceProcessingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isProcessing) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _animation,
            child: const Icon(
              Icons.face_retouching_natural,
              color: Colors.blue,
              size: 48,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mendeteksi Wajah...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.currentConfidence != null) ...[
            const SizedBox(height: 8),
            Text(
              'Mencocokkan: ${widget.currentConfidence!.toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

