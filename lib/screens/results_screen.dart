import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/trajet.dart';
import '../models/conditions_trafic.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/yango_estimate_service.dart';
import '../services/guide_service.dart';
import '../services/tip_service.dart';
import '../app_theme.dart';
import '../widgets/ai_guide_overlay.dart';
import 'navigation_screen.dart';

enum Priorite { economique, rapide, equilibre }

class ResultsScreen extends StatefulWidget {
  final List<Trajet> trajets;
  final String destination;
  final double? destLat;
  final double? destLon;
  final double? userLat;
  final double? userLon;
  final ConditionsTrafic conditions;

  const ResultsScreen({
    super.key,
    required this.trajets,
    required this.destination,
    this.destLat,
    this.destLon,
    this.userLat,
    this.userLon,
    this.conditions = const ConditionsTrafic(),
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  Priorite _priorite = Priorite.equilibre;
  bool _autoTheme = false;
  late List<Trajet> _options;
  YangoEstimate? _yangoEstimate;

  late AnimationController _listController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _options = widget.trajets;
    _loadSettings();

    if (widget.destLat != null &&
        widget.destLon != null &&
        widget.userLat != null &&
        widget.userLon != null) {
      _yangoEstimate = YangoEstimateService.estimer(
        userLat: widget.userLat!,
        userLon: widget.userLon!,
        destLat: widget.destLat!,
        destLon: widget.destLon!,
        heure: DateTime.now().hour,
      );
    }

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardAnimations = List.generate(3, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _listController,
          curve: Interval(i * 0.2, 0.6 + i * 0.2,
              curve: Curves.easeOutCubic),
        ),
      );
    });

    _listController.forward();
    GuideService().start();
    GuideService().showTip(TipService.instance.getTip(
      TipEvent.resultsShown,
      heure: DateTime.now().hour,
      conditions: widget.conditions,
      destination: widget.destination,
    ));
  }

  Future<void> _loadSettings() async {
    final auto = await SettingsService.getAutoTheme();
    if (!mounted) return;
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

  void _changerPriorite(Priorite p) {
    HapticFeedback.lightImpact();
    setState(() {
      _priorite = p;
      _options = List.from(_options)
        ..sort((a, b) => _scoreAvecPriorite(a, p)
            .compareTo(_scoreAvecPriorite(b, p)));
    });
    _listController.reset();
    _listController.forward();
  }

  double _scoreAvecPriorite(Trajet trajet, Priorite p) {
    switch (p) {
      case Priorite.economique:
        return (trajet.prixTotal * 3 + trajet.dureeTotal).toDouble();
      case Priorite.rapide:
        return (trajet.dureeTotal * 3 + trajet.prixTotal / 100).toDouble();
      case Priorite.equilibre:
        return (trajet.prixTotal * 1.5 + trajet.dureeTotal * 1.5).toDouble();
    }
  }

  Color _couleurResume(String resume) {
    if (resume.contains('Woro')) return const Color(0xFFFF6B2B);
    if (resume.contains('Gbaka')) return const Color(0xFF00C896);
    if (resume.contains('SOTRA')) return const Color(0xFF2196F3);
    return const Color(0xFFFF6B2B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              if (widget.conditions.actif) _buildConditionsBanner(),
              if (_options.isNotEmpty) _buildPrioriteFilter(),
              Expanded(
                child: _buildContenu(),
              ),
            ],
          ),
          if (GuideService().isActive)
            Positioned.fill(child: const AiGuideOverlay()),
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
            color: _isNight ? AppTheme.darkStroke : Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meilleurs trajets',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFFFF6B2B), size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '-> ${widget.destination}',
                        style: const TextStyle(
                          color: Color(0xFFFF6B2B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B2B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6B2B).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _options.isEmpty
                  ? 'Aucun trajet'
                  : '${_options.length + (_yangoEstimate != null ? 1 : 0)} option${_options.length + (_yangoEstimate != null ? 1 : 0) > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Color(0xFFFF6B2B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsBanner() {
    final tags = <String>[];
    if (widget.conditions.pluie) tags.add('🌧️ Pluie');
    if (widget.conditions.embouteillage) tags.add('🚦 Embouteillages');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B2B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFF6B2B).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: const Color(0xFFFF6B2B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Simulation active : ${tags.join(' · ')}'
              ' — les temps et le classement en tiennent compte.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFFF6B2B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioriteFilter() {
    final filters = [
      {'label': 'Economique', 'value': Priorite.economique},
      {'label': 'Rapide', 'value': Priorite.rapide},
      {'label': 'Equilibre', 'value': Priorite.equilibre},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _isNight ? AppTheme.darkStroke : Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: filters.map((f) {
          final isSelected = _priorite == f['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => _changerPriorite(f['value'] as Priorite),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [
                          Color(0xFFFF6B2B),
                          Color(0xFFFF8C55),
                        ])
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  f['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : _subTextColor,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContenu() {
    if (_options.isEmpty) {
      return _buildFallbackMarche();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _options.length + (_yangoEstimate != null ? 1 : 0),
      itemBuilder: (_, i) {
        if (_yangoEstimate != null && i == 0) {
          final estim = _yangoEstimate!;
          return AnimatedBuilder(
            animation: _cardAnimations.first,
            builder: (_, child) => Opacity(
              opacity: _cardAnimations.first.value,
              child: Transform.translate(
                offset: Offset(0, 40 * (1 - _cardAnimations.first.value)),
                child: child,
              ),
            ),
            child: _buildYangoCard(estim),
          );
        }

        final index = _yangoEstimate != null ? i - 1 : i;
        final anim = index < _cardAnimations.length
            ? _cardAnimations[index]
            : _cardAnimations.last;
        return AnimatedBuilder(
          animation: anim,
          builder: (_, child) => Opacity(
            opacity: anim.value,
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - anim.value)),
              child: child,
            ),
          ),
          child: _buildTrajetCard(_options[index], index),
        );
      },
    );
  }

  Widget _buildFallbackMarche() {
    final dist = LocationService.distanceEnMetres(
      lat1: widget.userLat ?? 0,
      lon1: widget.userLon ?? 0,
      lat2: widget.destLat ?? 0,
      lon2: widget.destLon ?? 0,
    );
    final tempsMarche = (dist / 4000 * 60).round();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF2196F3).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.directions_walk,
                    color: Color(0xFF2196F3), size: 40),
                const SizedBox(height: 12),
                Text(
                  'Aucune ligne directe disponible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aucune ligne de transport ne dessert '
                  'directement cette zone pour le moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _subTextColor, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_walk,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Trajet à pied : ~$tempsMarche min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '💡 Tu peux signaler un arrêt manquant\n'
            'pour améliorer TransitCI !',
            textAlign: TextAlign.center,
            style: TextStyle(color: _subTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildYangoCard(YangoEstimate estimate) {
    const couleur = Color(0xFFFFCC00);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: couleur.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.local_taxi, color: couleur, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yango (VTC)',
                    style: TextStyle(
                      color: couleur,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${estimate.prixMin} - ${estimate.prixMax} FCFA',
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildStat('FCFA', '${estimate.prixMin}', 'prix min', couleur),
                _buildDivider(),
                _buildStat('min', '${estimate.dureeMinutes}', 'duree', couleur),
                _buildDivider(),
                const Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.speed, color: Color(0xFFFFCC00), size: 18),
                      SizedBox(height: 4),
                      Text(
                        '~25 km/h',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrajetCard(Trajet trajet, int index) {
    final isMeilleur = index == 0;
    final couleur = _couleurResume(trajet.resume);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => NavigationScreen(
              trajet: trajet,
              destLat: widget.destLat ?? 0,
              destLon: widget.destLon ?? 0,
              userLat: widget.userLat,
              userLon: widget.userLon,
            ),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isMeilleur
              ? Border.all(color: couleur, width: 1.5)
              : Border.all(
                  color: _isNight
                      ? AppTheme.darkStroke
                      : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: isMeilleur
                  ? couleur.withValues(alpha: 0.15)
                  : _isNight
                      ? AppTheme.darkStroke
                      : Colors.black.withValues(alpha: 0.06),
              blurRadius: isMeilleur ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trajet.resume,
                                style: TextStyle(
                                  color: couleur,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isMeilleur) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: couleur,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Meilleur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (trajet.correspondances > 0)
                          Text(
                            '${trajet.correspondances} correspondance(s)',
                            style: TextStyle(
                                color: _subTextColor, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: couleur, size: 14),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _buildStat('', '${trajet.prixTotal}', 'FCFA', couleur),
                  _buildDivider(),
                  _buildStat('', '${trajet.dureeTotal}', 'min', couleur),
                  _buildDivider(),
                  _buildStat(
                      '', '${trajet.correspondances}', 'corresp.', couleur),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: trajet.segments
                    .where((s) => s.type != TypeSegment.piedVersDest)
                    .map((s) => _buildSegmentRow(s))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentRow(Segment s) {
    final isTransport = s.type == TypeSegment.transport;
    final color =
        isTransport ? const Color(0xFFFF6B2B) : const Color(0xFF00C896);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isTransport ? Icons.directions_bus : Icons.directions_walk,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.description,
              style: TextStyle(color: _subTextColor, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${s.dureeMinutes} min',
            style: TextStyle(
              color: _textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
      String emoji, String valeur, String label, Color couleur) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            valeur,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: _textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: _subTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: _isNight ? AppTheme.darkStroke : Colors.grey.shade200,
    );
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }
}
