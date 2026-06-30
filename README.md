# transit_ci

A new Flutter project.

## Getting Started

### Brancher l’application à votre projet Supabase

Pour utiliser votre propre instance Supabase au lieu du mode démo, lancez l’application avec les variables suivantes :

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://votre-projet.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=votre-cle-anon
```

Assurez-vous d’avoir les tables suivantes dans votre base Supabase :
- lignes
- vehicules_live


This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Bilan des travaux réalisés aujourd'hui

Ce projet a reçu plusieurs mises à jour liées aux assets, aux animations Lottie et à l'interface principale :

- Configuration et organisation des assets Flutter.
- Création et gestion des dossiers `assets/icons/` et `assets/lottie/`.
- Normalisation des noms de fichiers Lottie pour refléter leur fonction d'animation.
- Renommage du fichier Lottie de route en `assets/lottie/road_trip.json`.
- Vérification et mise à jour des chemins d'accès dans `pubspec.yaml`.
- Remplacement des spinners par des animations Lottie dans l'écran principal.
- Adaptation des icônes pour qu'elles correspondent aux attentes du code.
- Analyse et validation rapide via `flutter pub get` et `flutter analyze`.

> Ce bilan reprend les actions menées pendant la session d'aujourd'hui, avec un focus sur la cohérence des assets et la stabilité du rendu dans l'application.
