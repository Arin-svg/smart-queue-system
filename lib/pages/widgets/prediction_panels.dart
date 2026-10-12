import 'package:flutter/material.dart';
import 'clinic_widgets.dart';

class PredictionPanels extends StatelessWidget {
  const PredictionPanels(this.queues, {super.key});
  final List<Record> queues;
  @override
  Widget build(BuildContext context) {
    final total = queues.fold<num>(
      0,
      (sum, q) => sum + ((q['estimated_waiting_time'] as num?) ?? 0),
    );
    final learned = queues.any(
      (q) => '${q['estimate_method']}'.startsWith('AI:'),
    );
    final prediction = Panel(
      tint: const Color(0xFF009CB8),
      padding: 14,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white, fontSize: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 19, color: Colors.white),
            const SizedBox(height: 7),
            const Text(
              'Dynamic Wait Prediction',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              queues.isEmpty ? '—' : '~${(total / queues.length).round()} min',
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Average predicted wait'),
            const SizedBox(height: 10),
            Text(
              learned
                  ? 'AI estimates from clinic history'
                  : 'Clinic average until enough history is available',
            ),
          ],
        ),
      ),
    );
    final recommendations = Panel(
      padding: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.psychology_outlined,
            color: Color(0xFF9345FF),
            size: 19,
          ),
          const SizedBox(height: 7),
          const Text(
            'Intelligent Priority Recommendations',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          if (queues.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'No verified patients',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ...queues.take(3).map((q) {
            final recommendation = Record.from(
              q['priority_recommendation'] as Map? ?? {},
            );
            final level = recommendation['level'] as int?;
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q['queue_number']} · ${q['patient_name']}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    level == null
                        ? 'Manual review · learning pending'
                        : '${['Normal', 'Medium', 'High'][level.clamp(0, 2)]} · staff approval required',
                    style: TextStyle(
                      fontSize: 10,
                      color: level == 2 ? Colors.red : Colors.blueGrey,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          const Text(
            'Staff makes the final decision.',
            style: TextStyle(fontSize: 10, color: Colors.blueGrey),
          ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: prediction),
        const SizedBox(width: 8),
        Expanded(child: recommendations),
      ],
    );
  }
}
