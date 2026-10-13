import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ChatController extends ChangeNotifier {
  ChatController(this.api);
  final ApiService api;
  final List<Map<String, String>> messages = [];
  bool opened = false, busy = false, _disposed = false;
  String language = 'en';
  String? error, failedMessage;
  Map<String, dynamic>? context;

  void open() {
    opened = true;
    notifyListeners();
  }

  void minimize() {
    opened = false;
    notifyListeners();
  }

  void setLanguage(String value) {
    language = value;
    notifyListeners();
  }

  void clear() {
    if (busy) return;
    messages.clear();
    context = null;
    error = null;
    failedMessage = null;
    notifyListeners();
  }

  Future<void> send(String text) async {
    text = text.trim();
    if (busy || text.isEmpty || text.length > 2000) return;
    final history = messages.where((m) => m['failed'] != 'true').toList();
    final start = history.length > 10 ? history.length - 10 : 0;
    busy = true;
    error = null;
    failedMessage = null;
    final message = {'role': 'user', 'text': text};
    messages.add(message);
    notifyListeners();
    try {
      final result = await api.post('/ai/chat', {
        'message': text,
        'language': language,
        'history': history
            .skip(start)
            .map((m) => {'role': m['role'], 'text': m['text']})
            .toList(),
      });
      if (_disposed) return;
      final reply = result['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const ApiException(
          'Ask SQS returned an empty answer. Please try again.',
        );
      }
      messages.add({'role': 'model', 'text': reply});
      context = result['context'] is Map
          ? Map<String, dynamic>.from(result['context'])
          : null;
    } catch (e) {
      if (_disposed) return;
      message['failed'] = 'true';
      failedMessage = text;
      error = e is ApiException
          ? e.message
          : 'Unable to reach Ask SQS. Please try again.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> retry() async {
    final text = failedMessage;
    if (text == null || busy) return;
    if (messages.isNotEmpty && messages.last['failed'] == 'true') {
      messages.removeLast();
    }
    await send(text);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
