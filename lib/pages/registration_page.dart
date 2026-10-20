import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'widgets/clinic_widgets.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, this.staff = false, this.appointment});
  final bool staff;
  final Record? appointment;
  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _form = GlobalKey<FormState>();
  final _other = TextEditingController();
  String? token, department, reason, patient;
  bool checking = false;
  Record? booking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = ClinicScope.of(context).controller;
    final today = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 8))
        .toIso8601String()
        .substring(0, 10);
    final eligible = c
        .rows('appointments')
        .where(
          (a) =>
              a['appointment_status'] == 'confirmed' &&
              a['appointment_date'] == today &&
              !c
                  .rows('queues')
                  .any((q) => q['appointment_id'] == a['appointment_id']),
        )
        .toList();
    // Never silently choose between multiple bookings.
    booking =
        widget.appointment ?? (eligible.length == 1 ? eligible.single : null);
  }

  @override
  void initState() {
    super.initState();
    department = widget.appointment?['department_id']?.toString();
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    final appointment = booking;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ClinicScanner()),
    );
    if (result == null || !mounted) return;
    setState(() => checking = true);
    final c = ClinicScope.of(context).controller;
    if (appointment != null && !widget.staff) {
      final scope = ClinicScope.of(context);
      final checkedIn = await perform(
        context,
        () => c.submit('/queues', {
          'appointment_id': appointment['appointment_id'],
          'department_id': appointment['department_id'],
          'reason_for_visit': display(
            appointment['reason_for_visit'],
            'Appointment visit',
          ),
          'qr_token': result,
        }),
        success: 'You are checked in. Your queue number is ready.',
      );
      if (!mounted) return;
      setState(() => checking = false);
      if (checkedIn != null) {
        if (widget.appointment != null) Navigator.pop(context);
        scope.navigate('My Queue');
      }
      return;
    }
    final checked = await perform(
      context,
      () => c.api.post('/clinic/qr/validate', {'qr_token': result}),
    );
    if (mounted)
      setState(() {
        checking = false;
        if (checked != null) token = result;
      });
  }

  @override
  Widget build(BuildContext context) {
    final scope = ClinicScope.of(context);
    final c = scope.controller;
    return ClinicPage(
      title: widget.staff
          ? 'Register Walk-in Patient'
          : booking != null
          ? 'Appointment check-in'
          : 'Clinic check-in',
      children: [
        if (!widget.staff && token == null) ...[
          const SizedBox(height: 24),
          Panel(
            tint: const Color(0xFFEAFBF6),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Color(0xFF00AB84),
                ),
                const SizedBox(height: 20),
                Text(
                  booking != null
                      ? 'Appointment confirmed'
                      : 'Scan to Get Queue Number',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  booking != null
                      ? 'Scan when you arrive. We will use your booking details and give you a queue number automatically.'
                      : 'For a walk-in, scan the clinic QR code. If you have a booking, open Appointments and choose Check in.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: checking ? null : scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(
                      checking ? 'Verifying…' : 'Scan QR Code at Entrance',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ] else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Panel(
                  tint: Color(0xFFEAFBF6),
                  child: ListTile(
                    leading: Icon(
                      Icons.local_hospital_outlined,
                      color: Color(0xFF00AB84),
                    ),
                    title: Text('Welcome to PKU!'),
                    subtitle: Text('Select your department and reason below.'),
                  ),
                ),
                if (widget.staff)
                  ChoiceField(
                    label: 'Patient',
                    items: choices(c.rows('patients'), 'user_id', 'name'),
                    value: patient,
                    onChanged: (v) => setState(() => patient = v),
                  ),
                const Text(
                  'Choose Department',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ...c
                    .rows('departments')
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.all(16),
                            backgroundColor:
                                department == '${d['department_id']}'
                                ? const Color(0xFFE4FBF3)
                                : Colors.white,
                            side: BorderSide(
                              color: department == '${d['department_id']}'
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFFE4E6ED),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: widget.appointment != null
                              ? null
                              : () => setState(
                                  () => department = '${d['department_id']}',
                                ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_hospital_outlined),
                              const SizedBox(width: 12),
                              Expanded(child: Text('${d['department_name']}')),
                            ],
                          ),
                        ),
                      ),
                    ),
                if (c.rows('departments').isEmpty)
                  const Text('No departments are available.'),
                if (department != null) ...[
                  const SizedBox(height: 14),
                  ChoiceField(
                    label: 'Reason for Visit',
                    items: const [
                      ('General Checkup', 'General Checkup'),
                      ('Follow-up Visit', 'Follow-up Visit'),
                      ('Urgent Concern', 'Urgent Concern'),
                      ('Referral', 'Referral'),
                      ('Other', 'Other'),
                    ],
                    value: reason,
                    onChanged: (v) => setState(() => reason = v),
                  ),
                  if (reason == 'Other')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TextFormField(
                        controller: _other,
                        maxLength: 255,
                        decoration: const InputDecoration(
                          labelText: 'Reason for visit',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your reason'
                            : null,
                      ),
                    ),
                ],
                FilledButton.icon(
                  onPressed: department == null || reason == null || c.saving
                      ? null
                      : () async {
                          if (!_form.currentState!.validate()) return;
                          final result = await perform(
                            context,
                            () => c.submit('/queues', {
                              'department_id': int.parse(department!),
                              'reason_for_visit': reason == 'Other'
                                  ? _other.text.trim()
                                  : reason,
                              if (token != null) 'qr_token': token,
                              if (widget.staff) 'user_id': int.parse(patient!),
                              if (widget.appointment != null)
                                'appointment_id':
                                    widget.appointment!['appointment_id'],
                            }),
                          );
                          if (result != null && context.mounted) {
                            if (widget.staff || widget.appointment != null) {
                              Navigator.pop(context);
                            } else {
                              scope.navigate('My Queue');
                            }
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: Text(c.saving ? 'Registering…' : 'Get Queue Number'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ClinicScanner extends StatefulWidget {
  const ClinicScanner({super.key});
  @override
  State<ClinicScanner> createState() => _ClinicScannerState();
}

class _ClinicScannerState extends State<ClinicScanner> {
  bool scanned = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan Clinic QR Code')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Point your camera at the QR code displayed at PKU Entrance.',
          ),
        ),
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              if (scanned) return;
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  scanned = true;
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Camera unavailable. Allow camera access and try again, or ask registration staff to register your visit.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
