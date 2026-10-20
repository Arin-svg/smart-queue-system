import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controller/chat_controller.dart';

class ChatCompanionHost extends StatelessWidget {
  const ChatCompanionHost({
    super.key,
    required this.enabled,
    required this.controller,
    required this.navigate,
    required this.child,
  });
  final bool enabled;
  final ChatController controller;
  final void Function(String) navigate;
  final Widget child;
  @override
  Widget build(BuildContext context) => enabled
      ? ChatCompanion(controller: controller, navigate: navigate, child: child)
      : child;
}

class ChatCompanion extends StatefulWidget {
  const ChatCompanion({
    super.key,
    required this.controller,
    required this.navigate,
    required this.child,
  });
  final ChatController controller;
  final void Function(String) navigate;
  final Widget child;
  @override
  State<ChatCompanion> createState() => _ChatCompanionState();
}

class _ChatCompanionState extends State<ChatCompanion> {
  Offset position = const Offset(1, 1);
  final input = TextEditingController();
  final scroll = ScrollController();
  int messageCount = 0;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
  }

  void changed() {
    if (!widget.controller.opened) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (messageCount != widget.controller.messages.length ||
        widget.controller.busy) {
      messageCount = widget.controller.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void send([String? text]) {
    final value = text ?? input.text;
    if (value.trim().isEmpty || widget.controller.busy) return;
    input.clear();
    widget.controller.send(value);
  }

  void navigate(String page) {
    widget.controller.minimize();
    widget.navigate(page);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final c = widget.controller;
        final maxX = math.max(0.0, bounds.maxWidth - 80);
        final maxY = math.max(0.0, bounds.maxHeight - 80);
        return PopScope(
          canPop: !c.opened,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) c.minimize();
          },
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              if (!c.opened)
                Positioned(
                  left: 12 + position.dx * maxX,
                  top: 12 + position.dy * maxY,
                  child: GestureDetector(
                    onPanUpdate: (event) => setState(
                      () => position = Offset(
                        maxX == 0
                            ? 0
                            : (position.dx + event.delta.dx / maxX).clamp(0, 1),
                        maxY == 0
                            ? 0
                            : (position.dy + event.delta.dy / maxY).clamp(0, 1),
                      ),
                    ),
                    child: Tooltip(
                      message: 'Ask SQS — tap to chat, drag to move',
                      child: Material(
                        elevation: 6,
                        shadowColor: Colors.teal.withValues(alpha: .25),
                        color: const Color(0xFFD8FAEF),
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const Key('chat-bubble'),
                          customBorder: const CircleBorder(),
                          onTap: c.open,
                          child: const SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(child: CompanionAvatar(size: 42)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (c.opened) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: c.minimize,
                    child: Container(color: Colors.black26),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: SizedBox(
                    width: math.min(bounds.maxWidth, 480),
                    height: bounds.maxHeight,
                    child: Material(
                      color: const Color(0xFFF5F8F7),
                      elevation: 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            width: 34,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
                            child: Row(
                              children: [
                                const CompanionAvatar(size: 44),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ask SQS',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Your little companion',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF628078),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Chat options',
                                  onSelected: (value) {
                                    if (value == 'clear') {
                                      c.clear();
                                    } else {
                                      c.setLanguage(value);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    CheckedPopupMenuItem(
                                      value: 'en',
                                      checked: c.language == 'en',
                                      child: const Text('English'),
                                    ),
                                    CheckedPopupMenuItem(
                                      value: 'ms',
                                      checked: c.language == 'ms',
                                      child: const Text('Bahasa Melayu'),
                                    ),
                                    PopupMenuItem(
                                      value: 'clear',
                                      enabled: !c.busy,
                                      child: const Text('Clear conversation'),
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      c.language == 'en' ? 'EN' : 'BM',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Minimize chat',
                                  onPressed: c.minimize,
                                  icon: const Icon(Icons.remove),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView(
                              controller: scroll,
                              padding: const EdgeInsets.all(20),
                              children: [
                                if (c.messages.isEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: CompanionAvatar(size: 84),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    c.language == 'en'
                                        ? 'A little help, right here.'
                                        : 'Sedia membantu anda.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF183C37),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    c.language == 'en'
                                        ? 'Queues, appointments, and finding your way.'
                                        : 'Giliran, janji temu dan panduan aplikasi.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF628078),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                                _message(
                                  c.language == 'en'
                                      ? 'Hi! I’m SQS chatbot. What can I help you with today?'
                                      : 'Hai! Saya Chatbot SQS. Apa yang boleh saya bantu hari ini?',
                                  false,
                                ),
                                for (final m in c.messages)
                                  _message(
                                    m['text']!,
                                    m['role'] == 'user',
                                    failed: m['failed'] == 'true',
                                  ),
                                if (c.busy)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Ask SQS is thinking…'),
                                      ],
                                    ),
                                  ),
                                if (c.error != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEDEA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(c.error!),
                                        TextButton(
                                          onPressed: c.busy ? null : c.retry,
                                          child: const Text('Retry'),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (c.context?['next_appointment'] is Map)
                                  _appointmentCard(
                                    c.context!['next_appointment'] as Map,
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    key: const Key('chat-input'),
                                    controller: input,
                                    minLines: 1,
                                    maxLines: 3,
                                    maxLength: 2000,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => send(),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF1F6F4),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 15,
                                          ),
                                      counterText: '',
                                      hintText: c.language == 'en'
                                          ? 'Ask about SQS…'
                                          : 'Tanya tentang SQS…',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(24),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF00A88D),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF008B73),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(48, 48),
                                  ),
                                  tooltip: 'Send message',
                                  onPressed: c.busy ? null : () => send(),
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            color: Colors.white,
                            child: const SafeArea(
                              top: false,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Text(
                                  'AI can make mistakes. Verify important details with clinic staff.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget _message(String text, bool user, {bool failed = false}) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: EdgeInsets.only(
        bottom: 16,
        left: user ? 28 : 0,
        right: user ? 0 : 28,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(maxWidth: 350),
      decoration: BoxDecoration(
        color: user ? const Color(0xFF008B73) : Colors.white,
        border: user ? null : Border.all(color: const Color(0xFFE2EBE7)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(user ? 20 : 5),
          bottomRight: Radius.circular(user ? 5 : 20),
        ),
      ),
      child: Text(
        failed ? '$text\nNot answered' : text,
        style: TextStyle(
          color: user ? Colors.white : const Color(0xFF183C37),
          height: 1.4,
        ),
      ),
    ),
  );

  Widget _appointmentCard(Map appointment) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next appointment · from your account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${appointment['department_name']}'),
          Text(
            '${appointment['appointment_date']} · ${appointment['appointment_time']}',
          ),
          Text('${appointment['appointment_status']}'),
          TextButton(
            onPressed: () => navigate('Appts'),
            child: const Text('View appointment'),
          ),
        ],
      ),
    ),
  );
}

class CompanionAvatar extends StatelessWidget {
  const CompanionAvatar({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/sqs_robot.png',
    width: size,
    height: size,
    semanticLabel: 'SQS robot companion',
    fit: BoxFit.contain,
  );
}
