enum AppointmentStatus { booked, cancelled, completed }

class Appointment {
  const Appointment({
    required this.id,
    required this.patientId,
    required this.departmentId,
    required this.scheduledAt,
    this.doctorId,
    required this.status,
  });
  final int id;
  final int patientId;
  final int departmentId;
  final DateTime scheduledAt;
  final int? doctorId;
  final AppointmentStatus status;
}
