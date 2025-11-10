import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_colors.dart';
import '../../services/gemini_ai_service.dart';
import '../../core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupabaseClient _client = Supabase.instance.client;

  GeminiAIService? _aiService;
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeAIService();
    _addWelcomeMessage();
  }

  void _initializeAIService() {
    if (AppConfig.geminiApiKey != null && AppConfig.geminiApiKey!.isNotEmpty) {
      _aiService = GeminiAIService(AppConfig.geminiApiKey!);
    }
  }

  void _addWelcomeMessage() {
    _messages.add({
      'type': 'bot',
      'content':
          '¡Hola! Soy tu asistente de juegos. Puedo ayudarte a:\n\n'
          '• Buscar juegos por precio\n'
          '• Recomendar juegos según tu presupuesto\n'
          '• Comparar precios entre Steam y Epic\n'
          '• Dar consejos sobre cuándo comprar\n\n'
          '¿Qué te gustaría saber?',
      'timestamp': DateTime.now(),
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _aiService == null) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'Debes iniciar sesión para usar el chatbot');
      return;
    }

    // Add user message
    setState(() {
      _messages.add({
        'type': 'user',
        'content': message,
        'timestamp': DateTime.now(),
      });
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _generateAIResponse(message, user.id);
      setState(() {
        _messages.add({
          'type': 'bot',
          'content': response,
          'timestamp': DateTime.now(),
        });
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'type': 'bot',
          'content':
              'Lo siento, tuve un problema procesando tu mensaje. ¿Puedes intentarlo de nuevo?',
          'timestamp': DateTime.now(),
        });
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  Future<String> _generateAIResponse(String userMessage, String userId) async {
    // Get user's game data from Supabase
    final userGames = await _getUserGameData(userId);

    final prompt =
        """
Eres un asistente especializado en juegos de PC. El usuario te pregunta: "$userMessage"

Información del usuario:
- Juegos en wishlist: ${userGames['wishlist'].join(', ')}
- Búsquedas recientes: ${userGames['searches'].join(', ')}
- Juegos populares actuales: ${userGames['popular'].join(', ')}

Responde de manera útil y concisa. Si mencionan precios, enfócate en rangos realistas (€10-60 para juegos AAA, €5-30 para indie).
Si preguntan por recomendaciones, sugiere juegos específicos con precios aproximados.
Mantén un tono amigable y experto en gaming.
""";

    final response = await _aiService!.generateChatResponse(prompt);
    return response ??
        'Lo siento, no pude generar una respuesta en este momento.';
  }

  Future<Map<String, dynamic>> _getUserGameData(String userId) async {
    try {
      // Get wishlist
      final wishlistResponse = await _client
          .from('wishlist')
          .select('games(title)')
          .eq('user_id', userId)
          .limit(10);

      final wishlist = wishlistResponse
          .map((item) => item['games']['title'] as String)
          .toList();

      // Get recent searches
      final searchesResponse = await _client
          .from('user_searches')
          .select('query')
          .eq('user_id', userId)
          .order('searched_at', ascending: false)
          .limit(5);

      final searches = searchesResponse
          .map((item) => item['query'] as String)
          .toList();

      // Get popular games
      final popularResponse = await _client
          .from('games')
          .select('title')
          .order('created_at', ascending: false)
          .limit(5);

      final popular = popularResponse
          .map((item) => item['title'] as String)
          .toList();

      return {'wishlist': wishlist, 'searches': searches, 'popular': popular};
    } catch (e) {
      return {'wishlist': [], 'searches': [], 'popular': []};
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => Get.back(),
                    ),
                    const Expanded(
                      child: Text(
                        'Asistente IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),

            // Messages
            Expanded(
              child: Container(
                color: Colors.white,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _TypingIndicator();
                    }

                    final message = _messages[index];
                    return _MessageBubble(
                      message: message['content'],
                      isUser: message['type'] == 'user',
                      timestamp: message['timestamp'],
                    );
                  },
                ),
              ),
            ),

            // Input
            if (_aiService != null) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Pregunta sobre juegos y precios...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.primaryNeon,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppColors.primaryNeon,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () => _sendMessage(_messageController.text),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: const Center(
                  child: Text(
                    'El asistente IA no está disponible en este momento',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  const _MessageBubble({
    required this.message,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primaryNeon : AppColors.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isUser ? Colors.white : AppColors.primaryText,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isUser ? Colors.white70 : AppColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: const Radius.circular(4),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Text(
              'Escribiendo',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryNeon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
