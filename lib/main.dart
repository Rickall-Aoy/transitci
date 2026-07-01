import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'config/supabase_config.dart';
import 'screens/chauffeur/chauffeur_navigation.dart';
import 'screens/chauffeur/home_screen.dart' as chauffeur;
import 'screens/chauffeur/login_screen.dart';
import 'screens/chauffeur/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/passager/map_screen.dart';
import 'screens/passager/search_screen.dart';
import 'services/gtfs_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GtfsLoader.instance.initialize();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
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
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/passager/map': (context) => const MapScreen(),
        '/passager/search': (context) => const SearchScreen(),
        '/chauffeur/login': (context) => const LoginScreen(),
        '/chauffeur/register': (context) => const RegisterScreen(),
        '/chauffeur/home': (context) => const ChauffeurNavigation(),
        '/chauffeur': (context) => const ChauffeurNavigation(),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const _PlaceholderScreen(
          title: 'Page introuvable',
          message: 'Cette route n’existe pas encore.',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.traffic_outlined,
                size: 56,
                color: Color(0xFFFF6B00),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}