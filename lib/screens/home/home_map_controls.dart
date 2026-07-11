import 'package:flutter/material.dart';
import '../../app_theme.dart';

class HomeMapControls extends StatelessWidget {
  const HomeMapControls({
    super.key,
    required this.followUser,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleFollow,
    required this.selectingDepartureMode,
    required this.onToggleDepartureMode,
    this.hasCustomDeparture = false,
    this.onResetDeparture,
  });

  final bool followUser;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onToggleFollow;
  final bool selectingDepartureMode;
  final VoidCallback onToggleDepartureMode;
  final bool hasCustomDeparture;
  final VoidCallback? onResetDeparture;

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isNight ? AppTheme.darkSurfaceBright : Colors.white;
    final btnIcon = isNight ? AppTheme.darkTextPrimary : const Color(0xFF333333);
    final shadow = BoxShadow(
      color: isNight ? AppTheme.darkStroke : Colors.black.withAlpha(46),
      blurRadius: 12,
      offset: const Offset(0, 3),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          icon: Icons.add,
          onTap: onZoomIn,
          bg: btnBg,
          iconColor: btnIcon,
          shadow: shadow,
        ),
        const SizedBox(height: 12),
        _MapControlButton(
          icon: Icons.remove,
          onTap: onZoomOut,
          bg: btnBg,
          iconColor: btnIcon,
          shadow: shadow,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onToggleFollow,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: followUser
                  ? AppTheme.primary
                  : btnBg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [shadow],
            ),
            child: Icon(
              Icons.my_location,
              color: followUser ? Colors.white : btnIcon,
              size: 24,
            ),
          ),
        ),
        if (hasCustomDeparture || selectingDepartureMode) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: selectingDepartureMode ? onToggleDepartureMode : (onResetDeparture ?? onToggleDepartureMode),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selectingDepartureMode
                    ? AppTheme.primary
                    : (hasCustomDeparture ? AppTheme.primary.withValues(alpha: 0.15) : btnBg),
                borderRadius: BorderRadius.circular(14),
                border: hasCustomDeparture && !selectingDepartureMode
                    ? Border.all(color: AppTheme.primary, width: 1.5)
                    : null,
                boxShadow: [shadow],
              ),
              child: Icon(
                selectingDepartureMode ? Icons.close : Icons.location_pin,
                color: selectingDepartureMode
                    ? Colors.white
                    : (hasCustomDeparture ? AppTheme.primary : btnIcon),
                size: 22,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onTap,
    required this.bg,
    required this.iconColor,
    required this.shadow,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final Color iconColor;
  final BoxShadow shadow;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [shadow],
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
