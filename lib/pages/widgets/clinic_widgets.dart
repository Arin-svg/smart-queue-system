import 'package:flutter/material.dart';
import '../../controller/workspace_controller.dart';
import '../../services/api_service.dart';

export '../../controller/workspace_controller.dart'
    show Record, WorkspaceController;

class ClinicScope extends InheritedNotifier<WorkspaceController> {
  const ClinicScope({
    super.key,
    required WorkspaceController controller,
    required this.navigate,
    required this.role,
    required super.child,
  }) : super(notifier: controller);
  final void Function(String) navigate;
  final String role;
  static ClinicScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ClinicScope>()!;
  WorkspaceController get controller => notifier!;
}

String display(dynamic value, [String fallback = 'Not assigned']) =>
    value == null || '$value'.isEmpty ? fallback : '$value';
String label(dynamic value) => display(value, '')
    .split('_')
    .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
    .join(' ');
String elapsed(dynamic value) {
  final time = DateTime.tryParse('$value');
  if (time == null) return '—';
  final minutes = DateTime.now().difference(time).inMinutes.clamp(0, 99999);
  return minutes < 60 ? '$minutes min' : '${minutes ~/ 60}h ${minutes % 60}m';
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;

Future<Record?> perform(
  BuildContext context,
  Future<Record> Function() action, {
  String? success,
}) async {
  try {
    final result = await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ?? display(result['message'], 'Saved successfully.'),
          ),
        ),
      );
    }
    return result;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Unable to complete this action. Please try again.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
    return null;
  }
}

class ClinicPage extends StatelessWidget {
  const ClinicPage({
    super.key,
    required this.title,
    required this.children,
    this.action,
    this.onRefresh,
    this.enableRefresh = true,
  });
  final String title;
  final List<Widget> children;
  final Widget? action;
  final Future<void> Function()? onRefresh;
  final bool enableRefresh;
  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ?action,
            if (enableRefresh)
              IconButton(
                tooltip: 'Refresh',
                onPressed: c.loading ? null : onRefresh ?? c.refresh,
                icon: const Icon(Icons.refresh, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
    return enableRefresh
        ? RefreshIndicator(onRefresh: onRefresh ?? c.refresh, child: content)
        : content;
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.tint, this.padding = 18});
  final Widget child;
  final Color? tint;
  final double padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: tint ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7E8EE)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.check_circle_outline,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 46, color: Colors.blueGrey.shade200),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.blueGrey),
        ),
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'waiting' || 'pending' || 'skipped' => Colors.orange.shade800,
      'verified' || 'assigned' || 'called' => Colors.blue.shade700,
      'absent' ||
      'inactive' ||
      'cancelled' ||
      'unavailable' => Colors.red.shade700,
      _ => const Color(0xFF009C7A),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SummaryTiles extends StatelessWidget {
  const SummaryTiles(this.items, {super.key});
  final List<(String, String, Color)> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => SizedBox(
              width:
                  (constraints.maxWidth - (items.length - 1) * 8) /
                  items.length,
              child: Panel(
                padding: 10,
                tint: item.$3.withValues(alpha: .065),
                child: Column(
                  children: [
                    Icon(Icons.circle_outlined, color: item.$3, size: 18),
                    const SizedBox(height: 9),
                    Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: item.$3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.$1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class QueueCard extends StatelessWidget {
  const QueueCard(this.queue, {super.key, this.actions = const []});
  final Record queue;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final patient = ClinicScope.of(context).role == 'patient';
    final color = Theme.of(context).colorScheme.primary;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 76,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      display(queue['queue_number']),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (patient)
                      Text(
                        'Queue No.',
                        style: TextStyle(color: color, fontSize: 9),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!patient)
                      Text(
                        display(queue['patient_name']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    if (!patient)
                      Text(
                        display(queue['user_identifier'], ''),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.blueGrey,
                        ),
                      ),
                    InfoLine(
                      Icons.apartment,
                      display(queue['department_name']),
                    ),
                    InfoLine(
                      Icons.medical_services_outlined,
                      display(queue['doctor_name']),
                    ),
                    InfoLine(
                      Icons.meeting_room_outlined,
                      display(queue['room_name']),
                    ),
                    InfoLine(
                      Icons.schedule,
                      display(queue['registered_at'], ''),
                    ),
                    if (!patient && queue['reason_for_visit'] != null)
                      InfoLine(
                        Icons.notes_outlined,
                        '${queue['reason_for_visit']}',
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatusBadge('${queue['queue_status']}'),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      children: [
        Icon(icon, size: 15, color: Colors.blueGrey.shade400),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF707887)),
          ),
        ),
      ],
    ),
  );
}

class ChoiceField extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.optional = false,
  });
  final String label;
  final List<(String, String)> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool optional;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value:${items.map((e) => e.$1).join(',')}'),
      initialValue: items.any((e) => e.$1 == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        if (optional)
          const DropdownMenuItem(value: '', child: Text('Any / None')),
        ...items.map(
          (e) => DropdownMenuItem(
            value: e.$1,
            child: Text(e.$2, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
      validator: optional
          ? null
          : (v) => v == null || v.isEmpty ? 'Select $label' : null,
    ),
  );
}

List<(String, String)> choices(List<Record> rows, String id, String name) =>
    rows.map((r) => ('${r[id]}', display(r[name], ''))).toList();

Future<void> openClinicPage(BuildContext context, Widget page) {
  final scope = ClinicScope.of(context);
  final theme = Theme.of(context);
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => Theme(
        data: theme,
        child: ClinicScope(
          controller: scope.controller,
          navigate: scope.navigate,
          role: scope.role,
          child: Scaffold(
            appBar: AppBar(title: const Text('SQS')),
            body: page,
          ),
        ),
      ),
    ),
  );
}
