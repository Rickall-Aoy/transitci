import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GainsScreen extends StatefulWidget {
  const GainsScreen({super.key});

  @override
  State<GainsScreen> createState() => _GainsScreenState();
}

class _GainsScreenState extends State<GainsScreen> {
  final supabase = Supabase.instance.client;
  bool _chargement = true;
  List<Map<String, dynamic>> _trajets = [];
  double _totalSemaine = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final chauffeurId = supabase.auth.currentUser!.id;
      final ilYA7Jours = DateTime.now().subtract(const Duration(days: 7));

      final data = await supabase
          .from('trajets_historique')
          .select('*, lignes(nom)')
          .eq('chauffeur_id', chauffeurId)
          .eq('statut', 'termine')
          .gte('created_at', ilYA7Jours.toIso8601String())
          .order('created_at', ascending: false);

      final trajets = List<Map<String, dynamic>>.from(data);
      final total = trajets.fold<double>(
        0,
        (somme, t) => somme + (t['montant'] as num).toDouble(),
      );

      setState(() {
        _trajets = trajets;
        _totalSemaine = total;
      });
    } catch (e) {
      debugPrint('Erreur chargement gains: $e');
    }
    if (mounted) setState(() => _chargement = false);
  }

  String _formaterDate(String iso) {
    final date = DateTime.parse(iso).toLocal();
    final jours = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    final jour = jours[date.weekday - 1];
    final heure = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$jour, $heure';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        title: const Text('Mes gains'),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF8C3D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total des 7 derniers jours',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_totalSemaine.toStringAsFixed(0)} F',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_trajets.length} trajets effectués',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Historique',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0A0A0A)),
                  ),
                  const SizedBox(height: 10),
                  if (_trajets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Aucun trajet enregistré cette semaine',
                          style: TextStyle(color: Colors.black38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._trajets.map((trajet) {
                      final ligne = trajet['lignes'] as Map<String, dynamic>?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF3DE),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.directions_car_outlined,
                                size: 16,
                                color: Color(0xFFFF6B00),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ligne?['nom'] as String? ?? 'Ligne inconnue',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formaterDate(trajet['created_at'] as String),
                                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '+${(trajet['montant'] as num).toStringAsFixed(0)}F',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF6B00),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}