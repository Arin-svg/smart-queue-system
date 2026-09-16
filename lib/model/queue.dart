enum QueueStatus {
  waiting,
  verified,
  assigned,
  called,
  inConsultation,
  completed,
  skipped,
  absent,
}

class Queue {
  const Queue({
    required this.id,
    required this.number,
    required this.patientId,
    required this.departmentId,
    required this.createdAt,
    required this.status,
    this.doctorId,
    this.roomId,
  });
  final int id;
  final String number;
  final int patientId;
  final int departmentId;
  final DateTime createdAt;
  final QueueStatus status;
  final int? doctorId;
  final int? roomId;
}
