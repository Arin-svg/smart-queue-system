/// Extension point for a validated priority service.
/// No clinical priority decisions are implemented in this scaffold.
abstract interface class AiPriorityController {
  Future<int?> suggestPriority(int queueId);
}
