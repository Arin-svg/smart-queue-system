class Consultation {
  const Consultation({
    required this.id,
    required this.queueId,
    required this.doctorId,
    this.startedAt,
    this.completedAt,
  });
  final int id;
  final int queueId;
  final int doctorId;
  final DateTime? startedAt;
  final DateTime? completedAt;
}
