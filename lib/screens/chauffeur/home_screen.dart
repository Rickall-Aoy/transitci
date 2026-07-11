import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chauffeur_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;
  final ChauffeurService _service = ChauffeurService();

  bool _enService = false;
  bool _chargementInitial = true;
  String? _ligneSelectionnee;
  Timer? _gpsTimer;

  List<Map<String, dynamic>> _lignes = [];
  List<Map<String, dynamic>> _activitesRecentes = [];

  double _gainsAujourdhui = 0;
  int _nombreTrajets = 0;
  double _noteChauffeur = 0;
  int _tempsActifMinutes = 0;

  StreamSubscription? _activitesSub;
  StreamSubscription? _trajetsSub;

  @override
  void initState() {
    super.initState();
    _initialiser();
  }

  Future<void> _initialiser() async {
    await Future.wait([
      _chargerLignes(),
      _chargerStats(),
    ]);
    _ecouterActivitesTempsReel();
    _ecouterTrajetsTempsReel();
    setState(() => _chargementInitial = false);
  }

  Future<void> _chargerLignes() async {
    try {
      final lignes = await _service.recupererLignes();
      setState(() => _lignes = lignes);
    } catch (e) {
      debugPrint('Erreur chargement lignes: $e');
    }
  }

  Future<void> _chargerStats() async {
    try {
      final stats = await _service.recupererStatsJour();
      final note = await _service.recupererNoteMoyenne();
      final temps = await _service.recupererTempsActifMinutes();
      final activites = await _service.recupererActivitesRecentes();

      setState(() {
        _gainsAujourdhui = (stats['gains_jour'] as num).toDouble();
        _nombreTrajets = stats['nombre_trajets'] as int;
        _noteChauffeur = (note['note_moyenne'] as num).toDouble();
        _tempsActifMinutes = temps;
        _activitesRecentes = activites;
      });
    } catch (e) {
      debugPrint('Erreur chargement stats: $e');
    }
  }

  // Met à jour le fil d'activité en direct dès qu'une ligne change côté serveur
  void _ecouterActivitesTempsReel() {
    _activitesSub = _service.streamActivites().listen((data) {
      if (mounted) setState(() => _activitesRecentes = data);
    });
  }

  // Recalcule gains + nombre de trajets dès qu'un trajet est ajouté
  void _ecouterTrajetsTempsReel() {
    _trajetsSub = _service.streamTrajetsAujourdhui().listen((data) {
      if (!mounted) return;
      final termines = data.where((t) => t['statut'] == 'termine');
      final total = termines.fold<double>(
        0,
        (somme, t) => somme + (t['montant'] as num).toDouble(),
      );
      setState(() {
        _nombreTrajets = termines.length;
        _gainsAujourdhui = total;
      });
    });
  }

  Future<void> _toggleService() async {
    if (_ligneSelectionnee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez une ligne d\'abord')),
      );
      return;
    }

    if (_enService) {
      await _arreterService();
    } else {
      await _demarrerService();
    }
  }

  Future<void> _demarrerService() async {
    final permissionOk = await _demanderPermissionGPS();
    if (!permissionOk) return;

    try {
      await _service.demarrerSession(_ligneSelectionnee!);
      await _envoyerPosition();

      _gpsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _envoyerPosition();
      });

      setState(() => _enService = true);
    } catch (e) {
      if (!mounted) return;
      _afficherMessage('Erreur au démarrage: $e');
    }
  }

  Future<void> _arreterService() async {
    _gpsTimer?.cancel();
    _gpsTimer = null;

    try {
      await _service.supprimerPosition();
      await _service.arreterSession();
    } catch (e) {
      debugPrint('Erreur arrêt service: $e');
    }

    setState(() => _enService = false);
    await _chargerStats();
  }

  Future<bool> _demanderPermissionGPS() async {
    final serviceActif = await Geolocator.isLocationServiceEnabled();
    if (!serviceActif) {
      _afficherMessage('Activez la localisation sur votre téléphone');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _afficherMessage('Permission GPS refusée');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _afficherMessage('Permission GPS bloquée. Activez-la dans les réglages.');
      return false;
    }

    return true;
  }

  void _afficherMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _envoyerPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _service.envoyerPosition(
        ligneId: _ligneSelectionnee!,
        latitude: position.latitude,
        longitude: position.longitude,
        vitesse: position.speed,
      );
    } catch (e) {
      debugPrint('Erreur envoi position: $e');
    }
  }

  String _nomLigneSelectionnee() {
    if (_ligneSelectionnee == null) return '';
    final ligne = _lignes.firstWhere(
      (l) => l['id'] == _ligneSelectionnee,
      orElse: () => {},
    );
    return (ligne['nom'] as String?) ?? '';
  }

  String _formaterTempsActif() {
    final heures = _tempsActifMinutes ~/ 60;
    final minutes = _tempsActifMinutes % 60;
    if (heures == 0) return '${minutes}min';
    return '${heures}h${minutes.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _activitesSub?.cancel();
    _trajetsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      body: SafeArea(
        child: _chargementInitial
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _chargerStats,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12, width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                              _buildHeader(),
                          _buildBody(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ---------- En-tête ----------
  Widget _buildHeader() {
    final email = supabase.auth.currentUser?.email ?? '';
    final initiales = email.isNotEmpty ? email.substring(0, 2).toUpperCase() : '??';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFF8C3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car_filled,
                        color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Transit CI Pro',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0x40FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initiales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Prêt à démarrer ?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _noteChauffeur > 0 ? _formatNumber(_noteChauffeur, 1) : '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Corps principal ----------
  Widget _buildBody() {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          children: [
            _buildSelecteurLigne(),
            const SizedBox(height: 18),
            _buildBoutonService(),
            const SizedBox(height: 18),
            _buildStatsCards(),
            const SizedBox(height: 14),
            _buildActiviteRecente(),
            const SizedBox(height: 14),
            _buildBandeauConnexion(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelecteurLigne() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4F0),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.alt_route, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: _lignes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Aucune ligne disponible',
                        style: TextStyle(color: Colors.black38, fontSize: 13)),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _ligneSelectionnee,
                      hint: const Text('Sélectionner votre ligne'),
                      items: _lignes.map((ligne) {
                        return DropdownMenuItem<String>(
                          value: ligne['id'] as String,
                          child: Text(ligne['nom'] as String),
                        );
                      }).toList(),
                      onChanged: _enService
                          ? null
                          : (value) => setState(() => _ligneSelectionnee = value),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoutonService() {
    final couleurFond = _enService
        ? const Color(0xFFFCEBEB)
        : const Color(0xFFFFEDD9);
    final couleurPlein = _enService
        ? const Color(0xFFE24B4A)
        : const Color(0xFFFF6B00);

    return Column(
      children: [
        GestureDetector(
          onTap: _toggleService,
          child: SizedBox(
            width: 158,
            height: 158,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 158,
                  height: 158,
                  decoration: BoxDecoration(color: couleurFond, shape: BoxShape.circle),
                ),
                Container(
                  width: 138,
                  height: 138,
                  decoration: BoxDecoration(
                    color: couleurPlein,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _enService ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _enService ? 'En service' : 'Démarrer',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _enService ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _enService
                  ? 'En service — ${_nomLigneSelectionnee()}'
                  : 'Hors service',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icone: Icons.payments_outlined,
            couleurIcone: const Color(0xFFFF6B00),
            label: 'Gains aujourd\'hui',
            valeur: '${_formatNumber(_gainsAujourdhui, 0)} F',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icone: Icons.location_on_outlined,
            couleurIcone: const Color(0xFFFFA758),
            label: 'Trajets',
            valeur: '$_nombreTrajets',
            note: 'temps actif ${_formaterTempsActif()}',
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icone,
    required Color couleurIcone,
    required String label,
    required String valeur,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 16, color: couleurIcone),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(valeur,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0A0A0A))),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(fontSize: 11, color: Colors.black38)),
          ],
        ],
      ),
    );
  }

  Widget _buildActiviteRecente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Activité récente',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0A0A0A))),
        const SizedBox(height: 8),
        if (_activitesRecentes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Aucune activité pour le moment',
                style: TextStyle(fontSize: 12, color: Colors.black38)),
          )
        else
          ..._activitesRecentes.map((activite) {
            final type = activite['type'] as String;
            final estTrajet = type == 'trajet';
            final montant = activite['montant'];
            final montantFormatte = montant is num
                ? montant
                : num.tryParse(montant?.toString() ?? '');

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: estTrajet
                          ? const Color(0xFFFFEDD9)
                          : const Color(0xFFFFF3EA),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      estTrajet ? Icons.check : Icons.info_outline,
                      size: 14,
                      color: estTrajet
                          ? const Color(0xFFFF6B00)
                          : const Color(0xFFFFA758),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activite['titre'] as String,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF0A0A0A))),
                        const SizedBox(height: 1),
                        Text(
                          _formaterDate(activite['created_at'] as String),
                          style: const TextStyle(fontSize: 11, color: Colors.black38),
                        ),
                      ],
                    ),
                  ),
                  if (montantFormatte != null)
                    Text(
                      '+${montantFormatte.toStringAsFixed(0)}F',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B6D11),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _formatNumber(num? value, int digits) {
    if (value == null || !value.isFinite) return '0';
    return value.toStringAsFixed(digits);
  }

  String _formaterDate(String iso) {
    final date = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  Widget _buildBandeauConnexion() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 16, color: Color(0xFFFF6B00)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _enService
                  ? 'Connexion stable — position mise à jour toutes les 10s'
                  : 'GPS inactif — démarrez le service pour partager votre position',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B4718)),
            ),
          ),
        ],
      ),
    );
  }
}
