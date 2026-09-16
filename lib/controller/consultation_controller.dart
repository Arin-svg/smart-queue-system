import 'package:flutter/foundation.dart';
import '../model/consultation.dart';
import '../services/api_service.dart';

/// Foundation; data loading will be added with the Laravel integration.
class ConsultationController extends ChangeNotifier {
  ConsultationController(this.api);
  final ApiService api;
  final List<Consultation> _items = [];
  List<Consultation> get items => List.unmodifiable(_items);
}
