import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

typedef Record = Map<String, dynamic>;

/// Shared authenticated state. Polls only while the application is foregrounded.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.api);
  final ApiService api;
  Record data = {};
  String? error;
  bool loading = false;
  bool saving = false;
  bool _disposed = false;
  Timer? _timer;
  DateTime? updatedAt;

  List<Record> rows(String key) =>
      (data[key] as List? ?? []).map((e) => Record.from(e as Map)).toList();
  Record get profile => Record.from(data['user'] as Map? ?? {});
  void start() {
    refresh();
    resume();
  }

  void resume() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }

  void pause() => _timer?.cancel();
  Future<void> refresh() async {
    if (loading || _disposed) return;
    loading = true;
    notifyListeners();
    try {
      final result = await api.get('/workspace');
      if (_disposed) return;
      data = result;
      updatedAt = DateTime.now();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Unable to refresh clinic information. Please try again.';
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<Record> submit(String path, Record body) async {
    if (saving)
      throw const ApiException('Please wait for the current request.');
    saving = true;
    if (!_disposed) notifyListeners();
    try {
      final result = await api.post(path, body);
      await refresh();
      return result;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  static const activeStatuses = {
    'waiting',
    'verified',
    'assigned',
    'called',
    'in_consultation',
    'skipped',
  };
  List<Record> get activeQueues => rows(
    'queues',
  ).where((q) => activeStatuses.contains(q['queue_status'])).toList();
  List<Record> get orderedQueues {
    final list = rows('queues');
    list.sort((a, b) {
      final priority = ((b['priority'] ?? 0) as num).compareTo(
        (a['priority'] ?? 0) as num,
      );
      if (priority != 0) return priority;
      final time = '${a['registered_at']}'.compareTo('${b['registered_at']}');
      return time != 0
          ? time
          : (a['queue_id'] as num).compareTo(b['queue_id'] as num);
    });
    return list;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
