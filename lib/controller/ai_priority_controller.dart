/// Decision support only. A recommendation never changes approved queue order.
abstract interface class AiPriorityController {
  Future<int?> suggestPriority(int queueId);
}
