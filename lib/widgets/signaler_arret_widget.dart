import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/gare.dart';
import '../data/lignes_mock.dart';
import '../services/crowdsourcing_service.dart';
import '../app_theme.dart';

enum SignalerArretMode { ajout, probleme }

class SignalerArretWidget extends StatefulWidget {
  final double latitude;
  final double longitude;
  final bool isNight;
  final VoidCallback onSuccess;
  final SignalerArretMode mode;

  const SignalerArretWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isNight,
    required this.onSuccess,
    this.mode = SignalerArretMode.ajout,
  });

  @override
  State<SignalerArretWidget> createState() => _SignalerArretWidgetState();
}

class _SignalerArretWidgetState extends State<SignalerArretWidget> {
  final TextEditingController _nomController = TextEditingController();
  TransportType _typeSelectionne = TransportType.woroWoro;
  String? _ligneSelectionnee;
  bool _isLoading = false;

  Color get _bgColor => widget.isNight ? AppTheme.darkSurface : Colors.white;
  Color get _textColor =>
      widget.isNight ? AppTheme.darkTextPrimary : const Color(0xFF0A0A0A);
  Color get _subColor => widget.isNight ? AppTheme.darkTextSecondary : Colors.grey.shade600;
  Color get _surfaceColor =>
      widget.isNight ? AppTheme.darkSurfaceBright : const Color(0xFFF5F5F5);
  Color get _dividerColor =>
      widget.isNight ? AppTheme.darkStroke : Colors.grey.shade200;

  String _formatCoord(double value) => value.toStringAsFixed(4);

  bool get _isProbleme => widget.mode == SignalerArretMode.probleme;

  String _emojiType(TransportType t) {
    switch (t) {
      case TransportType.woroWoro:
        return '';
      case TransportType.gbaka:
        return '';
      case TransportType.sotra:
        return '';
      case TransportType.yango:
        return '';
    }
  }

  String _labelType(TransportType t) {
    switch (t) {
      case TransportType.woroWoro:
        return 'Woro-Woro';
      case TransportType.gbaka:
        return 'Gbaka';
      case TransportType.sotra:
        return 'SOTRA';
      case TransportType.yango:
        return 'Yango';
    }
  }

  Color _couleurType(TransportType t) {
    switch (t) {
      case TransportType.woroWoro:
        return const Color(0xFFFF6B2B);
      case TransportType.gbaka:
        return const Color(0xFF00C896);
      case TransportType.sotra:
        return const Color(0xFF2196F3);
      case TransportType.yango:
        return const Color(0xFFFFCC00);
    }
  }

  List<String> get _lignesDuType => lignesMock
      .where((l) => l.type == _typeSelectionne)
      .map((l) => l.id)
      .toList();

  Future<void> _soumettre() async {
    if (_nomController.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final success = await CrowdsourcingService.signalerArret(
      nom: _nomController.text.trim(),
      latitude: widget.latitude,
      longitude: widget.longitude,
      type: _typeSelectionne,
      ligneId: _ligneSelectionnee,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text(''),
              Text('Arret signale ! Merci pour ta contribution.'),
            ],
          ),
          backgroundColor: const Color(0xFF00C896),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erreur — verifie ta connexion.'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isNight ? AppTheme.darkStroke : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B2B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_location_alt,
                    color: Color(0xFFFF6B2B), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _isProbleme
                          ? 'Signaler un probleme'
                          : 'Signaler un arret',
                      style: TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Text(
                    '${_formatCoord(widget.latitude)}, ${_formatCoord(widget.longitude)}',
                    style: TextStyle(color: _subColor, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(_isProbleme ? 'Detail du probleme' : 'Nom de l\'arret',
              style: TextStyle(
                  color: _subColor, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dividerColor),
            ),
            child: TextField(
              controller: _nomController,
              cursorColor: AppTheme.primary,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: _surfaceColor,
                hintText: _isProbleme
                    ? 'Ex: Arret dangereux, manque de signalisation...'
                    : 'Ex: Carrefour CHU, Marche Cocody...',
                hintStyle: TextStyle(color: _subColor, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
          const SizedBox(height: 16),

          Text('Type de transport',
              style: TextStyle(
                  color: _subColor, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: TransportType.values.map((type) {
              final selected = _typeSelectionne == type;
              final couleur = _couleurType(type);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _typeSelectionne = type;
                    _ligneSelectionnee = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? couleur.withValues(alpha: 0.15) : _surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? couleur : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(_emojiType(type),
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(
                          _labelType(type),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? _textColor : _subColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          if (_lignesDuType.isNotEmpty) ...[
            Text('Ligne associee (optionnel)',
                style: TextStyle(
                    color: _subColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dividerColor),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _ligneSelectionnee,
                    hint: Text('Selectionner une ligne',
                        style: TextStyle(color: _subColor, fontSize: 13)),
                    dropdownColor: _bgColor,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Aucune ligne specifique',
                            style: TextStyle(color: _subColor, fontSize: 13)),
                      ),
                      ..._lignesDuType.map((id) {
                        final ligne = lignesMock.firstWhere((l) => l.id == id);
                        return DropdownMenuItem(
                          value: id,
                          child: Text(
                            ligne.nom,
                            style: TextStyle(color: _textColor, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        setState(() => _ligneSelectionnee = val),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF2196F3), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isProbleme
                        ? 'Votre signalement sera visible en attente de validation par la communaute.'
                        : 'Cet arret sera visible en attente de validation par la communaute.',
                    style:
                        TextStyle(color: _subColor, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          GestureDetector(
            onTap: _isLoading ? null : _soumettre,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _nomController.text.trim().isNotEmpty
                    ? const LinearGradient(colors: [
                        Color(0xFFFF6B2B),
                        Color(0xFFFF8C55),
                      ])
                    : null,
                color:
                    _nomController.text.trim().isEmpty ? _surfaceColor : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _nomController.text.trim().isNotEmpty
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFF6B2B).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isProbleme
                              ? Icons.report_problem
                              : Icons.add_location_alt,
                          color: _nomController.text.trim().isNotEmpty
                              ? Colors.white
                              : _subColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isProbleme
                              ? 'Envoyer le signalement'
                              : 'Signaler cet arret',
                          style: TextStyle(
                            color: _nomController.text.trim().isNotEmpty
                                ? Colors.white
                                : _subColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }
}
