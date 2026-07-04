import 'package:flutter/material.dart';

import '../../widgets/search_destination_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF111111) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
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
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: isNight ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const _TransportLegend(),
          const SizedBox(height: 16),
          _ActionButtons(
            onReportProblem: onReportProblem,
            onAddStop: onAddStop,
          ),
          const SizedBox(height: 16),
          SearchDestinationWidget(
            isNight: isNight,
            onDestinationSelected: onDestinationSelected,
          ),
          const SizedBox(height: 12),
          _GoButton(
            canSearch: canSearch,
            hasCurrentPosition: hasCurrentPosition,
            onGo: onGo,
          ),
        ],
      ),
    );
  }
}

class _TransportLegend extends StatelessWidget {
  const _TransportLegend();

  @override
  Widget build(BuildContext context) {
    final types = [
      {'emoji': 'Taxi', 'label': 'Woro-Woro', 'color': const Color(0xFFFF6B2B)},
      {'emoji': 'Bus', 'label': 'Gbaka', 'color': const Color(0xFF00C896)},
      {'emoji': 'SOTRA', 'label': 'SOTRA', 'color': const Color(0xFF2196F3)},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: types.map((t) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t['emoji'] as String,
              style: TextStyle(
                color: t['color'] as Color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              t['label'] as String,
              style: TextStyle(
                color: t['color'] as Color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onReportProblem,
    required this.onAddStop,
  });

  final VoidCallback onReportProblem;
  final VoidCallback onAddStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onReportProblem,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF161616),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_problem, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Signaler un probleme',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onAddStop,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B2B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ajouter un arret',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
}

class _GoButton extends StatelessWidget {
  const _GoButton({
    required this.canSearch,
    required this.hasCurrentPosition,
    required this.onGo,
  });

  final bool canSearch;
  final bool hasCurrentPosition;
  final VoidCallback? onGo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canSearch ? onGo : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canSearch
                ? [const Color(0xFFFF6B2B), const Color(0xFFFF8C55)]
                : [Colors.grey.shade800, Colors.grey.shade700],
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
}
