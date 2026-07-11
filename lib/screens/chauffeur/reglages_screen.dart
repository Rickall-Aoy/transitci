import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReglagesScreen extends StatelessWidget {
  const ReglagesScreen({super.key});

  Future<void> _deconnexion(BuildContext context) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirme == true) {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/chauffeur/login',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final initiales = email.isNotEmpty ? email.substring(0, 2).toUpperCase() : '??';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        title: const Text('Réglages'),
        backgroundColor: const Color(0xFFF5F4F0),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B00),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initiales,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mon profil',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0A0A0A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section('Compte', [
            _option(Icons.person_outline, 'Modifier mon profil'),
            _option(Icons.directions_car_outlined, 'Mon véhicule'),
            _option(Icons.lock_outline, 'Changer le mot de passe'),
          ]),
          const SizedBox(height: 16),
          _section('Préférences', [
            _option(Icons.notifications_outlined, 'Notifications'),
            _option(Icons.language_outlined, 'Langue'),
          ]),
          const SizedBox(height: 16),
          _section('Support', [
            _option(Icons.help_outline, 'Centre d\'aide'),
            _option(Icons.info_outline, 'À propos de Transit CI'),
          ]),
          const SizedBox(height: 24),
          Builder(
            builder: (ctx) => OutlinedButton.icon(
              onPressed: () => _deconnexion(ctx),
              icon: const Icon(Icons.logout, size: 18, color: Color(0xFFFF6B00)),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(color: Color(0xFFFF6B00)),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFFFF6B00)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String titre, List<Widget> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titre,
            style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12, width: 0.5),
          ),
          child: Column(children: options),
        ),
      ],
    );
  }

  Widget _option(IconData icone, String label) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icone, size: 19, color: Colors.black54),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}