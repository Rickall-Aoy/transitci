import 'dart:async';
import 'package:flutter/material.dart';
import '../services/guide_service.dart';

class AiGuideOverlay extends StatefulWidget {
  final String? targetWidget;
  final VoidCallback? onClose;
  final VoidCallback? onAction;

  const AiGuideOverlay({
    super.key,
    this.targetWidget,
    this.onClose,
    this.onAction,
  });

  @override
  State<AiGuideOverlay> createState() => _AiGuideOverlayState();
}

class _AiGuideOverlayState extends State<AiGuideOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  StreamSubscription<GuideMessage>? _subscription;
  GuideMessage? _currentMessage;
  Timer? _throttleTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _subscription = GuideService().stream.listen(
      _onMessage,
      onError: (error) {
        if (mounted) {
          setState(() => _currentMessage = null);
        }
      },
      cancelOnError: false,
    );
    _controller.forward();
  }

  void _onMessage(GuideMessage message) {
    if (!mounted) return;

    // Annule le timer précédent et planifie une mise à jour
    // → garantit que le dernier message passe TOUJOURS
    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      setState(() => _currentMessage = message);
      _controller.forward(from: 0);
    });
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) setState(() => _currentMessage = null);
    widget.onClose?.call();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _currentMessage;
    if (message == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Taille bornée = écran (via MediaQuery), indépendamment du parent.
    // Évite les deux erreurs possibles selon le placement : Stack non borné
    // (size.isFinite) et hauteur infinie (BoxConstraints h=Infinity).
    final screen = MediaQuery.of(context).size;
    return SizedBox(
      width: screen.width,
      height: screen.height,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Plus de backdrop plein écran : la carte ne bloque aucun tap
            // sur le reste de l'écran (dismiss via la croix de la carte).

            // Guide card
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E1E2E), const Color(0xFF2A2A3E)]
                          : [Colors.white, const Color(0xFFF8F9FA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with bot avatar
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'TransitBot Guide',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _dismiss,
                            child: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.9)
                              : const Color(0xFF333333),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      if (message.showActionButton && message.actionLabel != null) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              message.onAction?.call();
                              _dismiss();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(message.actionLabel!),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
