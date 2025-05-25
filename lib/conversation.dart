import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class ConversationPage extends StatefulWidget {
  @override
  _ConversationPageState createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final Color greenColor = Color(0xFF4CAF50);
  final TextEditingController controller = TextEditingController();
  final List<Map<String, dynamic>> currentMessages = [];
  final ScrollController scrollController = ScrollController();
  List<ChatSession> chatSessions = [];
  int? currentSessionId;
  bool isLoading = false;
  bool isFirstLoad = true;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  final List<String> suggestedQuestions = [
    "Quelles sont les conséquences d'une température trop élevée ?",
    "À quel niveau d'humidité et de temperature dois-je m'inquiéter ?",
    "Quels sont les risques d'un taux d'humidité trop bas ?",
    "Quel est le taux d'humidité idéal pour une habitation ?",
    "Comment la température affecte-t-elle la santé humaine ?",
    "Comment interpréter les variations de température dans un environnement fermé ?",
    "Que peut détecter un capteur de gaz comme le MQ2 ?",
    "Quels sont les signes d'une fuite de gaz inflammable ?",
    "Quels sont les gaz inflammables les plus courants dans les foyers ?",
    "À quel moment un gaz devient-il dangereux pour la santé ?",
    "Que faire en cas de suspicion de fuite de gaz ?",
    "Que mesure exactement le capteur MQ135 ?",
    "Quelle est la différence entre gaz polluants et inflammables ?",
    "Quels sont les effets des gaz polluants sur la santé ?",
    "Quels types de polluants l'on peut retrouver dans l'air intérieur ?",
    "Comment réduire la pollution de l'air chez soi ?",
    "Quels sont les symptômes d'une exposition prolongée à des gaz polluants ?",
    "Quelle est la différence entre fumée, gaz et vapeur ?",
    "Pourquoi la détection de fumée est-elle importante dans un système de surveillance ?",
    "Quels sont les dangers d'une exposition à la fumée ?",
    "Le capteur MQ2 peut-il détecter la fumée de cigarette ?",
    "Quels sont les conseils pour éviter les incendies domestiques ?",
    "Comment fonctionnent les capteurs de gaz comme MQ2 et MQ135 ?",
    "Comment placer correctement les capteurs environnementaux dans une maison ?",
    "Pourquoi surveiller la qualité de l'air est-il important ?",
    "Quels sont les avantages d'un système de surveillance environnementale ?",
    "Quels autres capteurs a l'exception du mq2 et mq135 puis-je utiliser pour surveiller mon environnement ?",
  ];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadChatSessions();
    if (chatSessions.isNotEmpty) {
      _loadChatSession(chatSessions.first.id);
    }
    setState(() => isFirstLoad = false);
  }

  Future<void> _loadChatSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessions = prefs.getStringList('chat_sessions') ?? [];

      setState(() {
        chatSessions =
            sessions
                .map((session) {
                  try {
                    final data = json.decode(session);
                    return ChatSession(
                      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch,
                      title: data['title']?.toString() ?? 'Kivi Assistant',
                      lastMessage: data['lastMessage']?.toString() ?? '',
                      createdAt:
                          DateTime.tryParse(
                            data['createdAt']?.toString() ?? '',
                          ) ??
                          DateTime.now(),
                      messages:
                          (data['messages'] as List? ?? []).map((msg) {
                            return {
                              'role': (msg['role']?.toString() ?? 'user'),
                              'message': (msg['message']?.toString() ?? ''),
                              'content':
                                  (msg['content']?.toString() ??
                                      msg['message']?.toString() ??
                                      ''),
                            };
                          }).toList(),
                    );
                  } catch (e) {
                    print('Error parsing session: $e');
                    return ChatSession(
                      id: DateTime.now().millisecondsSinceEpoch,
                      title: 'Session corrompue',
                      lastMessage: '',
                      createdAt: DateTime.now(),
                      messages: [],
                    );
                  }
                })
                .where(
                  (session) =>
                      session.messages.isNotEmpty ||
                      session.title != 'Session corrompue',
                )
                .toList();
      });
    } catch (e) {
      print('Error loading sessions: $e');
    }
  }

  Future<void> _saveChatSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'chat_sessions',
        chatSessions
            .map(
              (session) => json.encode({
                'id': session.id,
                'title': session.title,
                'lastMessage': session.lastMessage,
                'createdAt': session.createdAt.toIso8601String(),
                'messages':
                    session.messages
                        .map(
                          (m) => {
                            'role': m['role'],
                            'message': m['message'],
                            'content': m['content'],
                          },
                        )
                        .toList(),
              }),
            )
            .toList(),
      );
    } catch (e) {
      print('Error saving sessions: $e');
    }
  }

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void createNewChat() {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'Nouvelle conversation',
      lastMessage: '',
      createdAt: DateTime.now(),
      messages: [],
    );

    setState(() {
      currentSessionId = newSession.id;
      currentMessages.clear();
      chatSessions.insert(0, newSession);
    });
    _saveChatSessions();
  }

  void _loadChatSession(int sessionId) {
    try {
      final session = chatSessions.firstWhere((s) => s.id == sessionId);
      setState(() {
        currentSessionId = sessionId;
        currentMessages.clear();
        currentMessages.addAll(
          session.messages.map(
            (m) => {
              'role': m['role']!,
              'message': m['content'] ?? m['message'] ?? '',
            },
          ),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      print('Error loading session: $e');
    }
  }

  Future<void> deleteChat(int sessionId) async {
    setState(() {
      chatSessions.removeWhere((s) => s.id == sessionId);
      if (currentSessionId == sessionId) {
        currentSessionId = null;
        currentMessages.clear();
      }
    });
    await _saveChatSessions();
  }

  Future<void> renameChat(int sessionId, String newTitle) async {
    if (newTitle.trim().isEmpty) return;

    setState(() {
      final index = chatSessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        chatSessions[index].title = newTitle.trim();
        _saveChatSessions();
      }
    });
  }

  String _cleanResponse(String response) {
    final Map<String, String> replacements = {
      'Ã©': 'é',
      'Ã¨': 'è',
      'Ãª': 'ê',
      'Ã«': 'ë',
      'Ã®': 'î',
      'Ã¯': 'ï',
      'Ã´': 'ô',
      'Ã¶': 'ö',
      'Ã¹': 'ù',
      'Ã»': 'û',
      'Ã¼': 'ü',
      'Ã§': 'ç',
      'Ã€': 'À',
      'Ã‰': 'É',
      'Ãˆ': 'È',
      'ÃŠ': 'Ê',
      'Ã‹': 'Ë',
      'ÃŽ': 'Î',
      'ÃŒ': 'Ì',
      'Ã‘': 'Ñ',
      'Ã’': 'Ò',
      'Ã“': 'Ó',
      'Ã”': 'Ô',
      'Ã•': 'Õ',
      'Ã–': 'Ö',
      'Ã˜': 'Ø',
      'Ã™': 'Ù',
      'Ãš': 'Ú',
      'Ã›': 'Û',
      'Ãœ': 'Ü',
      'ÃŸ': 'ß',
      'Ã ': 'à',
      'Ã¢': 'â',
      'Â°': '°',
      'â€™': "'",
      'â€œ': '"',
      'â€�': '"',
      'â€“': '-',
      'â€¢': '-',
      'Ã¥': 'å',
      'Ã¦': 'æ',
      'Ã¸': 'ø',
      '#': '',
      '*': '',
      r'$1': '',
      r'\n': '\n',
      r'\"': '"',
    };

    replacements.forEach((key, value) {
      response = response.replaceAll(key, value);
    });

    response =
        response
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
            .trim();

    return response;
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty || currentSessionId == null) return;

    final userMessage = {
      "role": "user",
      "message": message.trim(),
      "content": message.trim(),
    };

    setState(() {
      isLoading = true;
      currentMessages.add(userMessage);
      _updateCurrentSession(lastMessage: message.trim());
      _scrollToBottom();
    });

    try {
      const String apiKey = 'dBObCMPR5e55GlrNQGdv9VR8pF98E3Vc';
      const String apiUrl = 'https://api.mistral.ai/v1/chat/completions';

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              "model": "mistral-medium",
              "messages":
                  currentMessages
                      .map(
                        (m) => {
                          "role": m["role"],
                          "content": m["content"] ?? m["message"] ?? '',
                        },
                      )
                      .toList(),
              "max_tokens": 2000,
              "temperature": 0.7,
            }),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String botMessage = _cleanResponse(
          (data['choices'][0]['message']['content'] as String).trim(),
        );

        setState(() {
          currentMessages.add({
            "role": "assistant",
            "message": botMessage,
            "content": botMessage,
          });
          _updateCurrentSession(lastMessage: botMessage);
          _scrollToBottom();
        });
      } else {
        throw Exception("Erreur ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      setState(() {
        currentMessages.add({
          "role": "assistant",
          "message": "Erreur: ${e.toString().split(':').first}",
          "content": "Erreur: ${e.toString().split(':').first}",
        });
        _updateCurrentSession();
      });
    } finally {
      setState(() => isLoading = false);
      controller.clear();
      _scrollToBottom();
    }
  }

  void _updateCurrentSession({String? lastMessage}) {
    final index = chatSessions.indexWhere((s) => s.id == currentSessionId);
    if (index != -1) {
      final session = chatSessions[index];
      chatSessions[index] = ChatSession(
        id: session.id,
        title:
            session.title == 'Nouvelle conversation' &&
                    currentMessages.isNotEmpty
                ? currentMessages.first['message'].length > 30
                    ? '${currentMessages.first['message'].substring(0, 30)}...'
                    : currentMessages.first['message']
                : session.title,
        lastMessage: lastMessage ?? session.lastMessage,
        createdAt: session.createdAt,
        messages: List.from(currentMessages),
      );
      _saveChatSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: colorScheme.surface,
      drawer: _buildDrawer(theme, isMobile),
      appBar: AppBar(
        title:
            currentSessionId != null
                ? Text(
                  chatSessions
                      .firstWhere((s) => s.id == currentSessionId)
                      .title,
                )
                : const Text('Kivi Assistant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (currentSessionId != null) {
              setState(() {
                currentSessionId = null;
                currentMessages.clear();
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              scaffoldKey.currentState?.openDrawer();
            },
          ),
          if (currentSessionId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteDialog(context),
            ),
        ],
      ),
      body:
          isFirstLoad
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child:
                        currentSessionId == null
                            ? _buildEmptyState(theme)
                            : ListView.builder(
                              controller: scrollController,
                              itemCount: currentMessages.length,
                              itemBuilder: (context, index) {
                                return _buildMessageBubble(
                                  currentMessages[index],
                                  theme,
                                );
                              },
                            ),
                  ),
                  if (currentSessionId != null) _buildInputArea(theme),
                ],
              ),
    );
  }

  Widget _buildDrawer(ThemeData theme, bool isMobile) {
    return Drawer(
      width: isMobile ? MediaQuery.of(context).size.width * 0.8 : 280,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 20, color: Colors.white),
                label: const Text(
                  'Nouvelle conversation',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  createNewChat();
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: chatSessions.length,
              itemBuilder: (context, index) {
                final session = chatSessions[index];
                return _buildChatSessionItem(session, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSessionItem(ChatSession session, ThemeData theme) {
    return ListTile(
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        session.lastMessage.isNotEmpty
            ? session.lastMessage.length > 30
                ? '${session.lastMessage.substring(0, 30)}...'
                : session.lastMessage
            : 'Nouvelle conversation',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (String choice) {
          if (choice == 'rename') {
            _showRenameDialog(session, context);
          } else if (choice == 'delete') {
            _showDeleteConfirmDialog(session.id, context);
          }
        },
        itemBuilder: (BuildContext context) {
          return [
            const PopupMenuItem<String>(
              value: 'rename',
              child: Text('Renommer'),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text('Supprimer', style: TextStyle(color: Colors.red)),
            ),
          ];
        },
      ),
      selected: currentSessionId == session.id,
      onTap: () {
        _loadChatSession(session.id);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('images/yoga_2.jpg', width: 100, height: 100),
                const SizedBox(height: 24),
                Text(
                  'Comment puis-je vous aider aujourd\'hui ?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  height: constraints.maxHeight * 0.5,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: suggestedQuestions.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildSuggestionItem(
                          suggestedQuestions[index],
                          theme,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Nouvelle conversation',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: createNewChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionItem(String text, ThemeData theme) {
    return Material(
      color: theme.colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          controller.text = text;
          if (currentSessionId == null) {
            createNewChat();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              sendMessage(text);
            });
          } else {
            sendMessage(text);
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, ThemeData theme) {
    final isUser = message["role"] == "user";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isUser ? greenColor : theme.colorScheme.secondary,
            child:
                isUser
                    ? const Icon(Icons.person, color: Colors.white)
                    : Image.asset('images/yoga_2.jpg'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? "Vous" : "Assistant",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  message["message"]!,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.copy,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: message["message"]!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Message copié')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Envoyez un message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: sendMessage,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: greenColor,
            child: IconButton(
              icon:
                  isLoading
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Icon(Icons.send, color: Colors.white),
              onPressed: isLoading ? null : () => sendMessage(controller.text),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(ChatSession session, BuildContext context) {
    final textController = TextEditingController(text: session.title);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renommer la conversation'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Nouveau nom',
              border: OutlineInputBorder(),
            ),
            maxLength: 30,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                renameChat(session.id, textController.text);
                Navigator.pop(context);
              },
              child: const Text('Valider'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmDialog(
    int sessionId,
    BuildContext context,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer cette conversation?'),
          content: const Text('Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                deleteChat(sessionId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer cette conversation ?'),
          content: const Text('Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                deleteChat(currentSessionId!);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class ChatSession {
  final int id;
  String title;
  String lastMessage;
  final DateTime createdAt;
  List<Map<String, dynamic>> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.createdAt,
    required this.messages,
  });
}
