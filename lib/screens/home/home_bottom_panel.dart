import 'package:flutter/material.dart';

import '../../widgets/search_destination_widget.dart';
import '../../app_theme.dart';
import '../../models/conditions_trafic.dart';

class HomeBottomPanel extends StatelessWidget {
  const HomeBottomPanel({
    super.key,
    required this.isNight,
    required this.canSearch,
    required this.hasCurrentPosition,
    required this.onReportProblem,
    required this.onAddStop,
    required this.onDestinationSelected,
    required this.onGo,
    this.hasCustomDeparture = false,
    this.onToggleDepartureMode,
    this.onResetDeparture,
    this.departureLabel,
    this.collapsed = false,
    this.onToggleCollapsed,
    this.conditions = const ConditionsTrafic(),
    required this.onConditionsChanged,
  });

  final bool isNight;
  final bool canSearch;
  final bool hasCurrentPosition;
  final bool hasCustomDeparture;
  final VoidCallback onReportProblem;
  final VoidCallback onAddStop;
  final void Function(String nom, double lat, double lon) onDestinationSelected;
  final VoidCallback? onGo;
  final VoidCallback? onToggleDepartureMode;
  final VoidCallback? onResetDeparture;
  final String? departureLabel;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;
  final ConditionsTrafic conditions;
  final ValueChanged<ConditionsTrafic> onConditionsChanged;

  Color get _textPrimary => isNight ? Colors.white : const Color(0xFF0A0A0A);
  Color get _textSecondary => isNight ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF3A3A3A);
  Color get _textTertiary => isNight ? Colors.white.withValues(alpha: 0.6) : Colors.grey.shade600;
  Color get _iconColor => isNight ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF555555);

  Widget _buildMessageAccueil() {
    final h = DateTime.now().hour;
    final salut = h < 12 ? 'Bonjour' : h < 18 ? 'Bonsoir' : 'Bonne nuit';
    return Text(
      '$salut 👋  Où veux-tu aller ?',
      style: TextStyle(
        color: _textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSearchBar() {
    return SearchDestinationWidget(
      isNight: isNight,
      onDestinationSelected: onDestinationSelected,
    );
  }

  Widget _buildDepartureIndicator() {
    if (!hasCustomDeparture || departureLabel == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onResetDeparture,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_pin, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              'Depuis : $departureLabel',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isNight ? AppTheme.darkSurfaceBright : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: conditions.actif
              ? AppTheme.primary.withValues(alpha: 0.5)
              : (isNight ? AppTheme.darkStroke : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                conditions.actif ? Icons.warning_amber_rounded : Icons.tune,
                size: 14,
                color: conditions.actif ? AppTheme.primary : _iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Simuler les conditions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: conditions.actif ? AppTheme.primary : _textSecondary,
                ),
              ),
              const Spacer(),
              if (conditions.actif)
                GestureDetector(
                  onTap: () =>
                      onConditionsChanged(const ConditionsTrafic()),
                  child: Text(
                    'Réinitialiser',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textTertiary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildToggleCarte(
                  emoji: '🌧️',
                  label: 'Pluie',
                  active: conditions.pluie,
                  onChanged: (v) =>
                      onConditionsChanged(conditions.copyWith(pluie: v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildToggleCarte(
                  emoji: '🚦',
                  label: 'Embouteillages',
                  active: conditions.embouteillage,
                  onChanged: (v) => onConditionsChanged(
                      conditions.copyWith(embouteillage: v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCarte({
    required String emoji,
    required String label,
    required bool active,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!active),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withValues(alpha: 0.12)
              : (isNight ? AppTheme.darkStroke : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppTheme.primary
                : (isNight ? Colors.white24 : Colors.grey.shade300),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active
                    ? AppTheme.primary
                    : (isNight ? Colors.white70 : Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                active ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: active
                    ? AppTheme.primary
                    : (isNight ? Colors.white38 : Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoButton() {
    return GestureDetector(
      onTap: canSearch ? onGo : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B2B), Color(0xFFFF8C55)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: canSearch
              ? [
                  const BoxShadow(
                    color: Color.fromRGBO(255, 107, 43, 0.4),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              hasCurrentPosition
                  ? 'Trouver le meilleur transport'
                  : 'Localisation en cours...',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendeDiscrete() {
    final types = [
      {'emoji': '🚕', 'label': 'Woro-Woro', 'color': const Color(0xFFFF6B2B)},
      {'emoji': '🚐', 'label': 'Gbaka', 'color': const Color(0xFF00C896)},
      {'emoji': '🚌', 'label': 'SOTRA', 'color': const Color(0xFF2196F3)},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: types.map((t) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t['emoji'] as String, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 3),
              Text(
                t['label'] as String,
                style: TextStyle(
                  color: (t['color'] as Color).withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMenuSecondaire() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onReportProblem,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isNight ? AppTheme.darkSurfaceBright : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_outlined,
                      size: 14,
                      color: _iconColor),
                  const SizedBox(width: 6),
                  Text(
                    'Signaler',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: onAddStop,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isNight ? AppTheme.darkSurfaceBright : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_outlined,
                      size: 14,
                      color: _iconColor),
                  const SizedBox(width: 6),
                  Text(
                    'Ajouter arrêt',
                    style: TextStyle(
                      fontSize: 11,
                      color: _textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF111111) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isNight ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              'Où veux-tu aller ?',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_up_rounded,
            color: _textTertiary,
            size: 22,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (onToggleCollapsed != null) {
          final isExpanding = details.velocity.pixelsPerSecond.dy < -80;
          if (isExpanding != collapsed) {
            onToggleCollapsed!();
          }
        }
      },
      child: AnimatedCrossFade(
        crossFadeState: collapsed ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 280),
        firstChild: _buildCollapsedBar(context),
        secondChild: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.62,
          ),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF111111) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -8)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isNight ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildMessageAccueil(),
                const SizedBox(height: 10),
                _buildDepartureIndicator(),
                _buildSearchBar(),
                const SizedBox(height: 10),
                _buildSimulationPanel(),
                const SizedBox(height: 10),
                _buildGoButton(),
                const SizedBox(height: 14),
                _buildLegendeDiscrete(),
                const SizedBox(height: 10),
                _buildMenuSecondaire(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
