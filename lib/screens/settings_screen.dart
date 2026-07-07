import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../app_theme.dart';
import 'tutorial_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoTheme = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    setState(() => _autoTheme = auto);
  }

  bool get _isNight {
    if (!_autoTheme) return false;
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  Color get _bgColor => _isNight ? AppTheme.darkBg : const Color(0xFFF5F5F5);
  Color get _cardColor => _isNight ? AppTheme.darkSurfaceBright : Colors.white;
  Color get _textColor => _isNight ? AppTheme.darkTextPrimary : const Color(0xFF0A0A0A);
  Color get _subTextColor => _isNight ? AppTheme.darkTextSecondary : Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('Apparence', [
                  _buildToggle(
                    icon: Icons.brightness_auto,
                    titre: 'Thème automatique',
                    description: 'Passe en mode nuit entre 19h et 6h',
                    valeur: _autoTheme,
                    couleur: const Color(0xFFFF6B2B),
                    onChanged: (val) async {
                      HapticFeedback.lightImpact();
                      await SettingsService.setAutoTheme(val);
                      setState(() => _autoTheme = val);
                    },
                  ),
                ]),

                const SizedBox(height: 8),

                _buildSection('A propos', [
                  _buildTile(
                    icon: Icons.play_circle_outline,
                    titre: 'Tutoriel',
                    description: 'Revoir comment utiliser TransitCI',
                    couleur: const Color(0xFF00C896),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, animation, __) =>
                              const TutorialScreen(fromSettings: true),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    icon: Icons.info_outline,
                    titre: 'Version',
                    description: 'TransitCI v1.0.0 — MVP Abidjan',
                    couleur: const Color(0xFF2196F3),
                    onTap: () {},
                  ),
                  _buildTile(
                    icon: Icons.favorite_outline,
                    titre: 'Fait avec a Abidjan',
                    description: 'Par l\'équipe TransitCI',
                    couleur: const Color(0xFFFF6B2B),
                    onTap: () {},
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 16, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: _isNight ? AppTheme.darkStroke : Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isNight ? AppTheme.darkStroke : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back, color: _textColor, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Paramètres',
            style: TextStyle(
              color: _textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String titre, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Text(
            titre,
            style: TextStyle(
              color: _subTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _isNight ? AppTheme.darkStroke : Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: _isNight ? AppTheme.darkStroke : Colors.grey.shade100,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required IconData icon,
    required String titre,
    required String description,
    required bool valeur,
    required Color couleur,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: couleur, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titre,
                    style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(description,
                    style: TextStyle(
                        color: _subTextColor, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: valeur,
            onChanged: onChanged,
            activeThumbColor: couleur,
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String titre,
    required String description,
    required Color couleur,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: couleur, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titre,
                      style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(description,
                      style: TextStyle(
                          color: _subTextColor, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: _subTextColor, size: 18),
          ],
        ),
      ),
    );
  }
}
