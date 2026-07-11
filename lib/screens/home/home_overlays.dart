import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';
import '../../app_theme.dart';

class HomeLoadingOverlay extends StatelessWidget {
  const HomeLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: LottieBuilder.asset(
                'assets/lottie/road_trip.json',
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (context, error, stack) {
                  return const CircularProgressIndicator(
                    color: Color(0xFFFF6B2B),
                    strokeWidth: 2,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const ShimmerText(),
            const SizedBox(height: 8),
            const Text(
              'Chargement de la carte...',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeSearchingOverlay extends StatelessWidget {
  const HomeSearchingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color.fromRGBO(255, 107, 43, 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: LottieBuilder.asset(
                  'assets/lottie/car_search.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (context, error, stack) {
                    return const CircularProgressIndicator(
                      color: Color(0xFFFF6B2B),
                      strokeWidth: 2,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Analyse en cours...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Recherche des meilleures options',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeAddStopButton extends StatelessWidget {
  const HomeAddStopButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6B2B), Color(0xFFFF8C55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(255, 107, 43, 0.4),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_location_alt,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class HomeErrorBanner extends StatelessWidget {
  const HomeErrorBanner({
    super.key,
    required this.message,
    this.onSettings,
  });

  final String message;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          if (onSettings != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSettings,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Paramètres'),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeDepartureBanner extends StatelessWidget {
  const HomeDepartureBanner({
    super.key,
    required this.departureLabel,
    required this.onReset,
    required this.isNight,
  });

  final String departureLabel;
  final VoidCallback onReset;
  final bool isNight;

  @override
  Widget build(BuildContext context) {
    final bgColor = isNight ? AppTheme.darkSurfaceBright : Colors.white;
    final textColor = isNight ? AppTheme.darkTextPrimary : const Color(0xFF0A0A0A);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      left: 20,
      right: 20,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Départ personnalisé',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      departureLabel,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.gps_fixed, size: 16),
                label: const Text(
                  'Réinitialiser',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeDepartureSelectionOverlay extends StatelessWidget {
  const HomeDepartureSelectionOverlay({
    super.key,
    required this.isNight,
  });

  final bool isNight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Appuie sur la carte pour définir le départ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerText extends StatelessWidget {
  const ShimmerText({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: const Color(0xFFFF6B2B),
      child: const Text(
        'TransitCI',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
