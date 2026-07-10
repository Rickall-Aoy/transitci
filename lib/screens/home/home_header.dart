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
    required this.onAutoThemeChanged,
  });

  final bool autoTheme;
  final bool isLoading;
  final ValueChanged<bool> onAutoThemeChanged;

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    'CI',
                    style: TextStyle(
                      color: Colors.white,
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
                    onChanged: onAutoThemeChanged,
                  ),
                  _HeaderIconButton(
                    icon: Icons.drive_eta,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/chauffeur/login');
                    },
                  ),
                  _HeaderIconButton(
                    icon: Icons.search,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, '/passager/search');
                    },
                  ),
                  if (GeminiConfig.transitBotEnabled)
                    _HeaderIconButton(
                      icon: Icons.smart_toy_outlined,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, '/assistant');
                      },
                    ),
                  _HeaderIconButton(
                    icon: Icons.settings,
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
                  const _GpsIndicator(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isLoading)
          const Text(
            'Ou veux-tu aller ?',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
      ],
    );
  }
}

class _AutoThemeButton extends StatelessWidget {
  const _AutoThemeButton({
    required this.autoTheme,
    required this.onChanged,
  });

  final bool autoTheme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
          color: autoTheme
              ? const Color.fromRGBO(255, 107, 43, 0.2)
              : const Color.fromRGBO(255, 255, 255, 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: autoTheme ? const Color(0xFFFF6B2B) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              autoTheme ? Icons.brightness_auto : Icons.wb_sunny,
              size: 12,
              color: autoTheme ? const Color(0xFFFF6B2B) : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              autoTheme ? 'Auto' : 'Jour',
              style: TextStyle(
                color: autoTheme ? const Color(0xFFFF6B2B) : Colors.white54,
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
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Color.fromRGBO(255, 255, 255, 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}

class _GpsIndicator extends StatelessWidget {
  const _GpsIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color.fromRGBO(0, 200, 150, 0.6),
        ),
      ),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: Color(0xFF00C896)),
            SizedBox(width: 4),
            Text(
              'GPS actif',
              style: TextStyle(
                color: Colors.white,
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
