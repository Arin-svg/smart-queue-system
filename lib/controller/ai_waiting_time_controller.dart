/// Extension point for prediction. Null means no estimate is available.
abstract interface class AiWaitingTimeController {
  Future<Duration?> estimateWaitingTime(int queueId);
}
