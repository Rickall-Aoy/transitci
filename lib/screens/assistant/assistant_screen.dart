import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../../config/gemini_config.dart';
import '../../services/gemini_service.dart';
import '../../services/guide_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isConfigured = false;
  bool _isStreaming = false;
  StreamSubscription<GuideMessage>? _guideSub;

  @override
  void initState() {
    super.initState();
    _initAssistant();
  }

  @override
  void dispose() {
    _guideSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initAssistant() async {
    final key = await GeminiConfig.apiKey;
    setState(() => _isConfigured = key.isNotEmpty);
    if (_isConfigured) await GeminiService.init();

    GuideService().start();

    if (mounted && _messages.isEmpty) {
      setState(() {
        _messages.add(
          _Message(
            text:
                "Salut ! 👋 Je suis TransitBot. Dis-moi d'où tu pars et où tu "
                "veux aller à Abidjan, je te propose le meilleur trajet en "
                "Woro-Woro, Gbaka, SOTRA ou Yango.",
            isUser: false,
          ),
        );
      });
    }
  }

  Future<void> _envoyer() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    _controller.clear();
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _isStreaming = true;
      _messages.add(_Message(text: '', isUser: false, isTyping: true));
    });
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;
    final context = _buildContext();

    await _guideSub?.cancel();
    GuideService().start();

    _guideSub = GuideService().askQuestionStream(text, context: context).listen(
      (msg) {
        if (!mounted) return;
        setState(() {
          _messages[assistantIndex] = _Message(
            text: msg.text.isEmpty ? '⚠️ Pas de réponse.' : msg.text,
            isUser: false,
            isTyping: false,
          );
        });
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _isStreaming = false);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _messages[assistantIndex] = _Message(
            text: '⚠️ Réponse indisponible.',
            isUser: false,
            isTyping: false,
          );
          _isStreaming = false;
        });
      },
    );
  }

  String _buildContext() {
    final h = DateTime.now().hour;
    final periode = h < 9 ? 'matin' : h < 17 ? 'journée' : h < 21 ? 'soir' : 'nuit';
    return 'Heure : ${h}h. Période : $periode. '
        'Position utilisateur : non renseignée ici. '
        'Préférence utilisateur : bus privilégié, accepte les correspondances.';
  }

  void _resetConversation() {
    GeminiService.resetChat();
    setState(() {
      _messages.clear();
      _messages.add(
        _Message(
          text: "Conversation réinitialisée. Comment puis-je t'aider ?",
          isUser: false,
        ),
      );
    });
  }

  Future<void> _ouvrirReglages() async {
    final controller = TextEditingController();
    final current = await GeminiConfig.apiKey;
    controller.text = current;

    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clé API Gemini'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colle ta clé API Google AI Studio. Elle est stockée '
              'localement sur l\'appareil.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'AIza...',
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null) {
      await GeminiConfig.setApiKey(result);
      final ok = await GeminiService.init();
      setState(() => _isConfigured = ok);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Clé enregistrée ✅' : 'Clé vide — assistant indisponible.',
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 15,
              child: Text('🤖', style: TextStyle(fontSize: 16)),
            ),
            SizedBox(width: 10),
            Text('TransitBot'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recherche classique',
            icon: const Icon(Icons.search),
            onPressed: () =>
                Navigator.pushNamed(context, '/passager/search'),
          ),
          IconButton(
            tooltip: 'Réinitialiser',
            icon: const Icon(Icons.refresh),
            onPressed: _isStreaming ? null : _resetConversation,
          ),
          IconButton(
            tooltip: 'Clé API',
            icon: Icon(_isConfigured ? Icons.key : Icons.key_off),
            onPressed: _ouvrirReglages,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConfigured)
            Container(
              width: double.infinity,
              color: AppTheme.warning.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Clé API Gemini non configurée.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _ouvrirReglages,
                    child: const Text('Configurer'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _MessageBubble(
                message: _messages[i],
                isNight: isNight,
              ),
            ),
          ),
          _InputBar(
            controller: _controller,
            isStreaming: _isStreaming,
            onSend: _envoyer,
          ),
        ],
      ),
    );
  }
}

class _Message {
  _Message({
    required this.text,
    required this.isUser,
    this.isTyping = false,
  });

  final String text;
  final bool isUser;
  final bool isTyping;
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({required this.message, required this.isNight});

  final _Message message;
  final bool isNight;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isNight = widget.isNight;

    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;

    final bubbleColor = message.isUser
        ? AppTheme.primary
        : (isNight ? AppTheme.darkSurfaceBright : Colors.white);

    final textColor = message.isUser
        ? Colors.white
        : (isNight ? AppTheme.darkTextPrimary : Colors.black87);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: message.isTyping
                  ? const _TypingIndicator()
                  : SelectableText(
                      message.text,
                      style:
                          TextStyle(color: textColor, fontSize: 14, height: 1.4),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _controller,
            curve: Interval(
              i * 0.3,
              (i * 0.3 + 0.5).clamp(0.0, 1.0),
              curve: Curves.easeInOut,
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.darkTextTertiary,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.isStreaming,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isStreaming;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final bg = isNight ? AppTheme.darkSurfaceBright : Colors.white;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: isNight ? AppTheme.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isNight ? AppTheme.darkStroke : Colors.grey.shade200,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Où veux-tu aller ?',
                  filled: true,
                  fillColor: bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isStreaming
                  ? Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(12),
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : InkWell(
                      key: const ValueKey('send'),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSend();
                      },
                      borderRadius: BorderRadius.circular(23),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(23),
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
