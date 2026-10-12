import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'widgets/clinic_widgets.dart';
import 'widgets/department_chart.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String start = DateTime.now().toIso8601String().substring(0, 10),
      end = DateTime.now().toIso8601String().substring(0, 10);
  String? department, error;
  Record? report;
  bool loading = false, exporting = false;
  int requestId = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (report == null && !loading && error == null) load();
  }

  Future<void> load() async {
    final id = ++requestId;
    setState(() {
      loading = true;
      error = null;
      report = null;
    });
    try {
      final result = await ClinicScope.of(context).controller.api.get(
        '/reports?start=$start&end=$end${department == null || department!.isEmpty ? '' : '&department_id=$department'}',
      );
      if (mounted && id == requestId) setState(() => report = result);
    } catch (_) {
      if (mounted && id == requestId) {
        setState(
          () => error =
              'Unable to generate report. Check the date range and retry.',
        );
      }
    } finally {
      if (mounted && id == requestId) setState(() => loading = false);
    }
  }

  Future<void> chooseDate(bool first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(first ? start : end),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (first) {
          start = picked.toIso8601String().substring(0, 10);
        } else {
          end = picked.toIso8601String().substring(0, 10);
        }
      });
      load();
    }
  }

  Future<void> download() async {
    final r = report;
    if (r == null || exporting) return;
    setState(() => exporting = true);
    try {
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Text(
              'SQS Queue Performance Report',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('${r['start']} to ${r['end']}'),
            pw.SizedBox(height: 20),
            pw.Text('Total queues: ${r['total']}'),
            pw.Text('Active: ${r['active']}'),
            pw.Text('Completed: ${r['completed']}'),
            pw.Text(
              'Average waiting time: ${r['average_wait_minutes'] ?? 'N/A'} min',
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Department', 'Queues'],
              data: (r['departments'] as List)
                  .map((d) => [d['name'], d['count']])
                  .toList(),
            ),
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'sqs-report-${r['start']}-${r['end']}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to download report.')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final r = report;
    final bars = (r?['departments'] as List? ?? [])
        .map((d) => Record.from(d as Map))
        .toList();
    return ClinicPage(
      title: 'Reports',
      onRefresh: load,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => chooseDate(true),
                icon: const Icon(Icons.calendar_month),
                label: Text('Start Date: $start'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => chooseDate(false),
                icon: const Icon(Icons.calendar_month),
                label: Text('End Date: $end'),
              ),
              const SizedBox(height: 16),
              ChoiceField(
                label: 'Department',
                optional: true,
                items: choices(
                  c.rows('departments'),
                  'department_id',
                  'department_name',
                ),
                value: department,
                onChanged: (v) {
                  setState(() => department = v);
                  load();
                },
              ),
              FilledButton(
                onPressed: loading ? null : load,
                child: const Text('Generate Report'),
              ),
            ],
          ),
        ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        if (r != null) ...[
          SummaryTiles([
            ('Total Queues', '${r['total']}', Colors.purple),
            ('Active', '${r['active']}', Colors.orange),
            ('Completed', '${r['completed']}', Colors.teal),
          ]),
          Panel(
            child: InfoLine(
              Icons.schedule,
              'Average Wait Time: ${r['average_wait_minutes'] ?? '—'} min',
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Queues by Department',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                DepartmentChart(bars),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: exporting ? null : download,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download Report'),
          ),
        ],
      ],
    );
  }
}
