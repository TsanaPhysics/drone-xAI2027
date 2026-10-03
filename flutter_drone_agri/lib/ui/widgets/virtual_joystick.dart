import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class VirtualJoystick extends StatefulWidget {
  final double size;
  final bool autoCenterY; // false for throttle stick
  final ValueChanged<Offset> onPositionChanged; // normalized x, y between -1.0 and 1.0

  const VirtualJoystick({
    super.key,
    this.size = 180.0,
    this.autoCenterY = true,
    required this.onPositionChanged,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _dragPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final double radius = widget.size / 2;
    const double thumbRadius = 28.0;
    final double maxDistance = radius - thumbRadius;

    return GestureDetector(
      onPanStart: (details) => _updateOffset(details.localPosition, radius, maxDistance),
      onPanUpdate: (details) => _updateOffset(details.localPosition, radius, maxDistance),
      onPanEnd: (_) {
        setState(() {
          if (widget.autoCenterY) {
            _dragPosition = Offset.zero;
            widget.onPositionChanged(Offset.zero);
          } else {
            // Keep Y, reset X to center
            _dragPosition = Offset(0, _dragPosition.dy);
            widget.onPositionChanged(Offset(0, _dragPosition.dy / maxDistance));
          }
        });
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardBg.withOpacity(0.6),
          border: Border.all(color: AppTheme.neonCyan.withOpacity(0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonCyan.withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Crosshairs
            Container(width: widget.size * 0.8, height: 1, color: AppTheme.neonCyan.withOpacity(0.2)),
            Container(height: widget.size * 0.8, width: 1, color: AppTheme.neonCyan.withOpacity(0.2)),
            
            // Thumb
            Transform.translate(
              offset: _dragPosition,
              child: Container(
                width: thumbRadius * 2,
                height: thumbRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [AppTheme.neonCyan, Color(0xFF0F172A)],
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.neonCyan.withOpacity(0.6),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateOffset(Offset localPos, double radius, double maxDistance) {
    final Offset delta = localPos - Offset(radius, radius);
    final double dist = delta.distance;

    Offset clamped = delta;
    if (dist > maxDistance) {
      clamped = Offset.fromDirection(delta.direction, maxDistance);
    }

    setState(() {
      _dragPosition = clamped;
    });

    final double normX = (clamped.dx / maxDistance).clamp(-1.0, 1.0);
    final double normY = (clamped.dy / maxDistance).clamp(-1.0, 1.0);
    widget.onPositionChanged(Offset(normX, normY));
  }
}
