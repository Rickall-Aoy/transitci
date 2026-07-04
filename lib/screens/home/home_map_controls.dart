import 'package:flutter/material.dart';

class HomeMapControls extends StatelessWidget {
  const HomeMapControls({
    super.key,
    required this.followUser,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleFollow,
  });

  final bool followUser;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(icon: Icons.add, onTap: onZoomIn),
        const SizedBox(height: 12),
        _MapControlButton(icon: Icons.remove, onTap: onZoomOut),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onToggleFollow,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: followUser
                  ? const Color(0xFFFF6B2B)
                  : Colors.white.withAlpha(243),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(46),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.my_location,
              color: followUser ? Colors.white : const Color(0xFF333333),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(243),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(46),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF333333), size: 24),
      ),
    );
  }
}
