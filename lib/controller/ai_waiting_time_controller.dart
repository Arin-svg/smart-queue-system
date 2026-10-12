/// Waiting-time prediction contract. Null means no current estimate is available.
abstract interface class AiWaitingTimeController {
  Future<Duration?> estimateWaitingTime(int queueId);
}
