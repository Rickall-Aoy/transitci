import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

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
