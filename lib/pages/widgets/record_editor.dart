import 'package:flutter/material.dart';
import 'clinic_widgets.dart';

class EditField {
  const EditField(
    this.keyName,
    this.title, {
    this.required = true,
    this.options,
    this.secret = false,
    this.initial,
    this.number = false,
  });
  final String keyName, title;
  final bool required, secret, number;
  final List<(String, String)>? options;
  final dynamic initial;
}

Future<void> editRecord(
  BuildContext context, {
  required String title,
  required String endpoint,
  required List<EditField> fields,
}) async {
  final c = ClinicScope.of(context).controller;
  final form = GlobalKey<FormState>();
  final values = <String, dynamic>{
    for (final f in fields) f.keyName: f.initial?.toString(),
  };
  bool saving = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final field in fields)
                    if (field.options != null)
                      ChoiceField(
                        label: field.title,
                        items: field.options!,
                        optional: !field.required,
                        value: values[field.keyName] as String?,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => values[field.keyName] = v),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextFormField(
                          initialValue: field.initial?.toString(),
                          obscureText: field.secret,
                          enabled: !saving,
                          keyboardType: field.number
                              ? TextInputType.number
                              : field.keyName == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          decoration: InputDecoration(labelText: field.title),
                          onChanged: (v) => values[field.keyName] = v,
                          validator: (v) {
                            if (field.required &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Enter ${field.title.toLowerCase()}';
                            }
                            if (field.secret &&
                                v != null &&
                                v.isNotEmpty &&
                                v.length < 8) {
                              return 'Use at least 8 characters';
                            }
                            if (field.keyName == 'email' &&
                                v != null &&
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(v)) {
                              return 'Enter a valid email';
                            }
                            if (field.number &&
                                v != null &&
                                v.isNotEmpty &&
                                int.tryParse(v) == null) {
                              return 'Enter a whole number';
                            }
                            return null;
                          },
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() => saving = true);
                    final payload = <String, dynamic>{};
                    for (final f in fields) {
                      final value = values[f.keyName];
                      if (f.secret && (value == null || value == '')) continue;
                      payload[f.keyName] = (value == null || value == '')
                          ? null
                          : (f.number || f.keyName.endsWith('_id'))
                          ? int.parse('$value')
                          : value;
                    }
                    final result = await perform(
                      context,
                      () => c.submit(endpoint, payload),
                    );
                    if (dialog.mounted) {
                      if (result != null) {
                        Navigator.pop(dialog);
                      } else {
                        setState(() => saving = false);
                      }
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
