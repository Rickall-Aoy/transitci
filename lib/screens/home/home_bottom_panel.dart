import 'package:flutter/material.dart';

import '../../widgets/search_destination_widget.dart';
import '../../app_theme.dart';

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
  });

  final bool isNight;
  final bool canSearch;
  final bool hasCurrentPosition;
  final VoidCallback onReportProblem;
  final VoidCallback onAddStop;
  final void Function(String nom, double lat, double lon) onDestinationSelected;
  final VoidCallback? onGo;

  Color get _textColor => isNight ? Colors.white : const Color(0xFF0A0A0A);

  Widget _buildMessageAccueil() {
    final h = DateTime.now().hour;
    final salut = h < 12 ? 'Bonjour' : h < 18 ? 'Bonsoir' : 'Bonne nuit';
    return Text(
      '$salut 👋  Où veux-tu aller ?',
      style: TextStyle(
        color: _textColor,
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
                  color: (t['color'] as Color).withOpacity(0.7),
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
                color: isNight ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_outlined,
                      size: 14,
                      color: isNight ? Colors.white54 : Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Signaler',
                    style: TextStyle(
                      fontSize: 11,
                      color: isNight ? Colors.white54 : Colors.grey.shade600,
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
                color: isNight ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_outlined,
                      size: 14,
                      color: isNight ? Colors.white54 : Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Ajouter arrêt',
                    style: TextStyle(
                      fontSize: 11,
                      color: isNight ? Colors.white54 : Colors.grey.shade600,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF111111) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -8)),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
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
          const SizedBox(height: 12),
          _buildSearchBar(),
          const SizedBox(height: 10),
          _buildGoButton(),
          const SizedBox(height: 14),
          _buildLegendeDiscrete(),
          const SizedBox(height: 10),
          _buildMenuSecondaire(),
        ],
      ),
    );
  }
}
