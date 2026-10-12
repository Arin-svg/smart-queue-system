import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../controller/clinic_qr_controller.dart';
import 'widgets/clinic_widgets.dart';

class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});
  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  ClinicQrController? _qr;
  DateTime? _lastWorkspaceRefresh;
  bool exporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workspace = ClinicScope.of(context).controller;
    final firstLoad = _qr == null;
    _qr ??= ClinicQrController(workspace.api);
    if (firstLoad || workspace.updatedAt != _lastWorkspaceRefresh) {
      _lastWorkspaceRefresh = workspace.updatedAt;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _qr!.load();
      });
    }
  }

  @override
  void dispose() {
    _qr?.dispose();
    super.dispose();
  }

  Future<void> export(bool print) async {
    final qr = _qr!;
    if (!qr.canExport || exporting) return;
    final token = qr.token!;
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
                  data: token,
                  width: 280,
                  height: 280,
                ),
                pw.SizedBox(height: 24),
                pw.Text('Valid until replaced by the clinic administrator.'),
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

  Future<void> replace() async {
    final qr = _qr!;
    if (qr.busy || exporting) return;
    if (qr.token != null) {
      final approved = await confirm(
        context,
        'Replace Clinic QR Code?',
        'The current code and its printed copies will stop working. Print and display the new code after replacing it.',
      );
      if (!approved || !mounted) return;
    }
    await perform(context, qr.replace);
  }

  @override
  Widget build(BuildContext context) {
    final admin = ClinicScope.of(context).role == 'administrator';
    final qr = _qr!;
    return ListenableBuilder(
      listenable: qr,
      builder: (context, _) => ClinicPage(
        title: 'Clinic QR Code',
        enableRefresh: false,
        children: [
          FilledButton.icon(
            onPressed: qr.canExport && !exporting ? () => export(true) : null,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
          const SizedBox(height: 24),
          if (qr.busy) const LinearProgressIndicator(),
          if (qr.error != null)
            Panel(
              child: Column(
                children: [
                  Text(
                    qr.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: qr.busy ? null : qr.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (qr.token != null) ...[
            Panel(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: QrImageView(
                    key: ValueKey(qr.token),
                    data: qr.token!,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(24),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'This code stays the same until an administrator replaces it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ),
          ] else if (!qr.busy && qr.error == null)
            EmptyState(
              'No Clinic QR Code Yet',
              admin
                  ? 'Generate the clinic QR code once, then print it for registration.'
                  : 'An administrator must generate the clinic QR code first.',
              icon: Icons.qr_code,
            ),
          OutlinedButton.icon(
            onPressed: qr.canExport && !exporting ? () => export(false) : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download QR Code'),
          ),
          if (admin) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: qr.busy || exporting || qr.error != null
                  ? null
                  : replace,
              icon: const Icon(Icons.qr_code_2),
              label: Text(
                qr.token == null ? 'Generate QR Code' : 'Replace QR Code',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
