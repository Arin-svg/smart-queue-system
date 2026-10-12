import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_queue_system/controller/workspace_controller.dart';
import 'package:smart_queue_system/services/api_service.dart';

void main() {
  test(
    'Failed refresh preserves data and marks it stale; recovery clears error',
    () async {
      final api = _Api();
      final controller = WorkspaceController(api);
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.rows('queues'), hasLength(3));
      api.fail = true;
      await controller.refresh();
      expect(controller.error, 'Offline');
      expect(controller.rows('queues'), hasLength(3));
      api.fail = false;
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.orderedQueues.map((r) => r['queue_id']), [3, 1, 2]);
    },
  );
  test(
    'Duplicate submissions are rejected until current action completes',
    () async {
      final api = _Api();
      final controller = WorkspaceController(api);
      addTearDown(controller.dispose);
      final action = controller.submit('/queues', {});
      expect(controller.saving, isTrue);
      await expectLater(
        controller.submit('/queues', {}),
        throwsA(isA<ApiException>()),
      );
      api.pending.complete({'message': 'Saved'});
      await action;
      expect(controller.saving, isFalse);
    },
  );
}

class _Api implements ApiService {
  bool fail = false;
  final pending = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> get(String path) async {
    if (fail) throw const ApiException('Offline');
    return {
      'queues': [
        {
          'queue_id': 2,
          'priority': 0,
          'registered_at': '2026-10-05 08:00:00',
          'queue_status': 'waiting',
        },
        {
          'queue_id': 1,
          'priority': 0,
          'registered_at': '2026-10-05 08:00:00',
          'queue_status': 'verified',
        },
        {
          'queue_id': 3,
          'priority': 2,
          'registered_at': '2026-10-05 08:30:00',
          'queue_status': 'assigned',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      pending.future;
}
