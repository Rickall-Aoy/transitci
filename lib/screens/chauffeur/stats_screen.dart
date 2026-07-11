import 'package:flutter/material.dart';
import '../../services/chauffeur_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ChauffeurService _service = ChauffeurService();
  bool _chargement = true;

  int _trajetsAujourdhui = 0;
  double _gainsAujourdhui = 0;
  double _noteMoyenne = 0;
  int _nombreAvis = 0;
  int _tempsActifMinutes = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final stats = await _service.recupererStatsJour();
      final note = await _service.recupererNoteMoyenne();
      final temps = await _service.recupererTempsActifMinutes();

      setState(() {
        _trajetsAujourdhui = stats['nombre_trajets'] as int;
        _gainsAujourdhui = (stats['gains_jour'] as num).toDouble();
        _noteMoyenne = (note['note_moyenne'] as num).toDouble();
        _nombreAvis = note['nombre_avis'] as int;
        _tempsActifMinutes = temps;
      });
    } catch (e) {
      debugPrint('Erreur chargement stats: $e');
    }
    if (mounted) setState(() => _chargement = false);
  }

  String _formaterTempsActif() {
    final heures = _tempsActifMinutes ~/ 60;
    final minutes = _tempsActifMinutes % 60;
    if (heures == 0) return '${minutes}min';
    return '${heures}h${minutes.toString().padLeft(2, '0')}';
  }

  String _formatNumber(dynamic value, {int fractionDigits = 0}) {
    if (value == null) return '';
    if (value is num) return value.toStringAsFixed(fractionDigits);
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed.toStringAsFixed(fractionDigits);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: const Color(0xFFF5F4F0),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _carteStat(
                          icone: Icons.payments_outlined,
                          couleur: const Color(0xFFFF6B00),
                          label: 'Gains aujourd\'hui',
                          valeur: '${_formatNumber(_gainsAujourdhui, fractionDigits: 0)} F',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _carteStat(
                          icone: Icons.local_taxi_outlined,
                          couleur: const Color(0xFFFFA758),
                          label: 'Trajets',
                          valeur: '$_trajetsAujourdhui',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _carteStat(
                          icone: Icons.access_time,
                          couleur: const Color(0xFF854F0B),
                          label: 'Temps actif',
                          valeur: _formaterTempsActif(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _carteStat(
                          icone: Icons.star_border,
                          couleur: const Color(0xFFD4A017),
                          label: 'Note moyenne',
                          valeur: _noteMoyenne > 0
                              ? _formatNumber(_noteMoyenne, fractionDigits: 1)
                              : '—',
                          sousTexte: '$_nombreAvis avis',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black12, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Revenu moyen par trajet',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _trajetsAujourdhui > 0
                              ? '${_formatNumber(_gainsAujourdhui / _trajetsAujourdhui, fractionDigits: 0)} F'
                              : '— F',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _carteStat({
    required IconData icone,
    required Color couleur,
    required String label,
    required String valeur,
    String? sousTexte,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(valeur,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0A0A0A))),
          if (sousTexte != null) ...[
            const SizedBox(height: 2),
            Text(sousTexte, style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ],
      ),
    );
  }
}