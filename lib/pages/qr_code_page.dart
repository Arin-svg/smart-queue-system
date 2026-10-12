import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'widgets/clinic_widgets.dart';

class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});
  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  String? token, expires;
  bool exporting = false;
  Future<void> export(bool print) async {
    if (token == null || exporting) return;
    setState(() => exporting = true);
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (_) => pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'Smart Queue System',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text('Scan at PKU Entrance to Get Your Queue Number'),
                pw.SizedBox(height: 30),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: token!,
                  width: 280,
                  height: 280,
                ),
                pw.SizedBox(height: 24),
                pw.Text('Expires: $expires'),
              ],
            ),
          ),
        ),
      );
      final bytes = await pdf.save();
      if (print) {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: 'Clinic QR Code',
        );
      } else {
        await Printing.sharePdf(bytes: bytes, filename: 'clinic-qr-code.pdf');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to export the QR code. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ClinicScope.of(context).controller;
    final valid =
        token != null &&
        (DateTime.tryParse(expires ?? '')?.isAfter(DateTime.now()) ?? false);
    return ClinicPage(
      title: 'Clinic QR Code',
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: c.saving
                    ? null
                    : () async {
                        final result = await perform(
                          context,
                          () => c.submit('/clinic/qr', {}),
                          success: 'Clinic QR code refreshed.',
                        );
                        if (result != null && mounted) {
                          setState(() {
                            token = result['token'] as String;
                            expires = result['expires_at'] as String;
                          });
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: valid && !exporting ? () => export(true) : null,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        if (valid)
          Panel(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: QrImageView(
                  data: token!,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ),
          )
        else
          const EmptyState(
            'Generate Clinic QR Code',
            'Refresh to create a new registration code. Codes expire after 15 minutes.',
            icon: Icons.qr_code,
          ),
        if (token != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              'Expires: $expires',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
        OutlinedButton.icon(
          onPressed: valid && !exporting ? () => export(false) : null,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download QR Code'),
        ),
      ],
    );
  }
}
