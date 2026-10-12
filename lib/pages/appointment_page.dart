import 'package:flutter/material.dart';
import 'widgets/clinic_widgets.dart';
import 'registration_page.dart';

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key});
  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final _form = GlobalKey<FormState>();
  final reason = TextEditingController();
  String? department, doctor, date, time;
  List<String> slots = [];
  bool loadingSlots = false;
  String? slotError;
  int generation = 0;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> loadSlots() async {
    final request = ++generation;
    setState(() {
      time = null;
      slots = [];
      slotError = null;
    });
    if (department == null || date == null) return;
    setState(() => loadingSlots = true);
    try {
      final result = await ClinicScope.of(context).controller.api.get(
        '/appointments/slots?department_id=$department&date=$date${doctor == null || doctor!.isEmpty ? '' : '&doctor_id=$doctor'}',
      );
      if (mounted && request == generation) {
        setState(() => slots = (result['slots'] as List).cast<String>());
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => slotError = 'Unable to load available times. Please retry.',
        );
      }
    } finally {
      if (mounted && request == generation) {
        setState(() => loadingSlots = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final doctorIds = c
        .rows('rooms')
        .where(
          (r) =>
              '${r['department_id']}' == department &&
              r['status'] == 'available',
        )
        .map((r) => '${r['doctor_id']}')
        .toSet();
    return ClinicPage(
      title: 'Appointments',
      children: [
        Panel(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BOOK NEW APPOINTMENT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 20),
                ChoiceField(
                  label: 'Department',
                  items: choices(
                    c.rows('departments'),
                    'department_id',
                    'department_name',
                  ),
                  value: department,
                  onChanged: (v) {
                    setState(() {
                      department = v;
                      doctor = null;
                    });
                    loadSlots();
                  },
                ),
                ChoiceField(
                  label: 'Doctor (Optional)',
                  optional: true,
                  items: choices(
                    c
                        .rows('doctors')
                        .where((d) => doctorIds.contains('${d['user_id']}'))
                        .toList(),
                    'user_id',
                    'name',
                  ),
                  value: doctor,
                  onChanged: (v) {
                    setState(() => doctor = v);
                    loadSlots();
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(date ?? '') ?? now,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null && mounted) {
                      setState(
                        () => date = picked.toIso8601String().substring(0, 10),
                      );
                      loadSlots();
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(date ?? 'Select Date'),
                ),
                const SizedBox(height: 14),
                if (loadingSlots) const LinearProgressIndicator(),
                if (slotError != null)
                  TextButton(
                    onPressed: loadSlots,
                    child: Text('$slotError Retry'),
                  ),
                ChoiceField(
                  label: 'Available Time',
                  items: slots.map((s) => (s, s)).toList(),
                  value: time,
                  onChanged: loadingSlots
                      ? null
                      : (v) => setState(() => time = v),
                ),
                if (date != null &&
                    !loadingSlots &&
                    slots.isEmpty &&
                    slotError == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'No available slots for this selection. Choose another date or doctor.',
                    ),
                  ),
                TextFormField(
                  controller: reason,
                  maxLength: 255,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Visit',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a reason for your visit'
                      : null,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: c.saving || time == null
                      ? null
                      : () async {
                          if (!_form.currentState!.validate()) return;
                          final result = await perform(
                            context,
                            () => c.submit('/appointments', {
                              'department_id': int.parse(department!),
                              if (doctor != null && doctor!.isNotEmpty)
                                'doctor_id': int.parse(doctor!),
                              'appointment_date': date,
                              'appointment_time': time,
                              'reason_for_visit': reason.text.trim(),
                            }),
                          );
                          if (result != null && mounted) {
                            reason.clear();
                            loadSlots();
                          }
                        },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Book Appointment'),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text(
            'My Appointments',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (c.rows('appointments').isEmpty)
          const EmptyState(
            'No appointments',
            'Your bookings will appear here.',
          ),
        ...c
            .rows('appointments')
            .map(
              (a) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      display(a['department_name']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge('${a['appointment_status']}'),
                    InfoLine(
                      Icons.calendar_month,
                      '${a['appointment_date']}  ${a['appointment_time']}',
                    ),
                    InfoLine(
                      Icons.person_outline,
                      display(a['doctor_name'], 'Any available doctor'),
                    ),
                    if ([
                      'confirmed',
                      'pending',
                    ].contains(a['appointment_status']))
                      Wrap(
                        spacing: 8,
                        children: [
                          if (a['appointment_date'] ==
                              DateTime.now().toIso8601String().substring(0, 10))
                            TextButton.icon(
                              onPressed: () => openClinicPage(
                                context,
                                RegistrationPage(appointment: a),
                              ),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Check In'),
                            ),
                          TextButton(
                            onPressed: c.saving
                                ? null
                                : () async {
                                    if (await confirm(
                                          context,
                                          'Cancel appointment?',
                                          'Cancel this appointment on ${a['appointment_date']}?',
                                        ) &&
                                        context.mounted) {
                                      await perform(
                                        context,
                                        () => c.submit(
                                          '/appointments/${a['appointment_id']}/cancel',
                                          {},
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Cancel Appointment'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
