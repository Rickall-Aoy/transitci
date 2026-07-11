import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/settings_service.dart';
import '../../config/gemini_config.dart';
import '../settings_screen.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.autoTheme,
    required this.isLoading,
    required this.isNight,
    required this.onAutoThemeChanged,
  });

  final bool autoTheme;
  final bool isLoading;
  final bool isNight;
  final ValueChanged<bool> onAutoThemeChanged;

  @override
  Widget build(BuildContext context) {
    final accentText = isNight ? Colors.white : const Color(0xFF0A0A0A);
    final subtitleText = isNight ? Colors.white70 : Colors.grey.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B2B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Transit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CI',
                    style: TextStyle(
                      color: accentText,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AutoThemeButton(
                    autoTheme: autoTheme,
                    isNight: isNight,
                    onChanged: onAutoThemeChanged,
                  ),
                  _HeaderIconButton(
                    icon: Icons.drive_eta,
                    isNight: isNight,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/chauffeur/login');
                    },
                  ),
                  _HeaderIconButton(
                    icon: Icons.search,
                    isNight: isNight,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/passager/search');
                    },
                  ),
                  if (GeminiConfig.transitBotEnabled)
                    _HeaderIconButton(
                      icon: Icons.smart_toy_outlined,
                      isNight: isNight,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, '/assistant');
                      },
                    ),
                  _HeaderIconButton(
                    icon: Icons.settings,
                    isNight: isNight,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _GpsIndicator(isNight: isNight),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isLoading)
          Text(
            'Ou veux-tu aller ?',
            style: TextStyle(color: subtitleText, fontSize: 13),
          ),
      ],
    );
  }
}

class _AutoThemeButton extends StatelessWidget {
  const _AutoThemeButton({
    required this.autoTheme,
    required this.isNight,
    required this.onChanged,
  });

  final bool autoTheme;
  final bool isNight;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final onSurface = isNight ? Colors.white54 : Colors.grey.shade700;
    final pillBg = autoTheme
        ? const Color.fromRGBO(255, 107, 43, 0.2)
        : (isNight
            ? const Color.fromRGBO(255, 255, 255, 0.15)
            : Colors.grey.shade200);
    final pillBorder = autoTheme
        ? const Color(0xFFFF6B2B)
        : (isNight ? Colors.white24 : Colors.grey.shade300);

    return GestureDetector(
      onTap: () async {
        final newValue = !autoTheme;
        await SettingsService.setAutoTheme(newValue);
        onChanged(newValue);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: pillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              autoTheme ? Icons.brightness_auto : Icons.wb_sunny,
              size: 12,
              color: autoTheme ? const Color(0xFFFF6B2B) : onSurface,
            ),
            const SizedBox(width: 5),
            Text(
              autoTheme ? 'Auto' : 'Jour',
              style: TextStyle(
                color: autoTheme ? const Color(0xFFFF6B2B) : onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.isNight,
    required this.onTap,
  });

  final IconData icon;
  final bool isNight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isNight
        ? const Color.fromRGBO(255, 255, 255, 0.15)
        : Colors.grey.shade200;
    final iconColor = isNight ? Colors.white70 : const Color(0xFF333333);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }
}

class _GpsIndicator extends StatelessWidget {
  const _GpsIndicator({required this.isNight});

  final bool isNight;

  @override
  Widget build(BuildContext context) {
    final bg = isNight
        ? const Color.fromRGBO(255, 255, 255, 0.15)
        : Colors.grey.shade200;
    final textColor = isNight ? Colors.white : const Color(0xFF0A0A0A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Color.fromRGBO(0, 200, 150, 0.6),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, size: 7, color: Color(0xFF00C896)),
            const SizedBox(width: 4),
            Text(
              'GPS actif',
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
