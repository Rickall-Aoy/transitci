import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'config/supabase_config.dart';
import 'services/arret_service.dart';
import 'screens/chauffeur/chauffeur_navigation.dart';
import 'screens/assistant/assistant_screen.dart';
import 'screens/chauffeur/login_screen.dart';
import 'screens/chauffeur/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/passager/map_screen.dart';
import 'screens/passager/search_screen.dart';
import 'screens/demo_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 App démarrage...');
  debugPrint('Supabase URL: ${SupabaseConfig.url}');
  debugPrint('Supabase key présente: ${SupabaseConfig.anonKey.isNotEmpty}');

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  debugPrint('✅ Supabase OK');

  // Chargement des arrêts (44 gares) + walking edges en ARRIÈRE-PLAN, une seule
  // fois. Non bloquant : l'UI démarre immédiatement et le routing enrichit les
  // correspondances dès que le cache est prêt (échec/lenteur sans impact).
  unawaited(ArretService.instance.initialize());

  runApp(const TransitCIApp());
}

class TransitCIApp extends StatelessWidget {
  const TransitCIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transit CI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/passager/map': (context) => const MapScreen(),
        '/passager/search': (context) => const SearchScreen(),
        '/chauffeur/login': (context) => const LoginScreen(),
        '/chauffeur/register': (context) => const RegisterScreen(),
        '/chauffeur/home': (context) => const ChauffeurNavigation(),
        '/chauffeur': (context) => const ChauffeurNavigation(),
        '/assistant': (context) => const AssistantScreen(),
        '/demo': (context) => const DemoScreen(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const _PlaceholderScreen(
          title: 'Page introuvable',
          message: 'Cette route n\'existe pas encore.',
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final bg = isNight ? AppTheme.darkSurface : Colors.white;
    final textColor = isNight ? AppTheme.darkTextPrimary : const Color(0xFF0A0A0A);
    final subText = isNight ? AppTheme.darkTextSecondary : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.traffic_outlined,
                size: 56,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: subText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
