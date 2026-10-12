import 'package:flutter/material.dart';
import 'clinic_widgets.dart';

/// Vertical department distribution, matching Figure 3.33.
class DepartmentChart extends StatelessWidget {
  const DepartmentChart(this.rows, {super.key});
  final List<Record> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty)
      return const Text('No queues recorded in this date range.');
    final maximum = rows.fold<num>(
      1,
      (m, d) => (d['count'] as num) > m ? d['count'] as num : m,
    );
    final ceiling = ((maximum / 4).ceil() * 4).toDouble();
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            height: 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                5,
                (i) => Text(
                  '${(ceiling * (4 - i) / 4).round()}',
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth / rows.length).clamp(
                  70.0,
                  160.0,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width * rows.length,
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              5,
                              (_) => const Divider(
                                height: 1,
                                color: Color(0xFFE4E5ED),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: rows
                              .map(
                                (d) => SizedBox(
                                  width: width,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: 200,
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Tooltip(
                                            message:
                                                '${d['name']}: ${d['count']}',
                                            child: Container(
                                              width: width * .65,
                                              height:
                                                  195 *
                                                  (d['count'] as num) /
                                                  ceiling,
                                              decoration: BoxDecoration(
                                                color: color,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(6),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          '${d['name']}',
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
