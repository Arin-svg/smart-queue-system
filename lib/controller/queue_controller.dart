import 'package:flutter/foundation.dart';
import '../model/queue.dart';
import '../services/api_service.dart';

/// Foundation; data loading will be added with the Laravel integration.
class QueueController extends ChangeNotifier {
  QueueController(this.api);
  final ApiService api;
  final List<Queue> _items = [];
  List<Queue> get items => List.unmodifiable(_items);
}
