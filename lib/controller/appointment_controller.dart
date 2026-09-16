import 'package:flutter/foundation.dart';
import '../model/appointment.dart';
import '../services/api_service.dart';

/// Foundation; data loading will be added with the Laravel integration.
class AppointmentController extends ChangeNotifier {
  AppointmentController(this.api);
  final ApiService api;
  final List<Appointment> _items = [];
  List<Appointment> get items => List.unmodifiable(_items);
}
