import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/preview/preview_service.dart';
import '../layout.dart';

class PreviewSettingsPage extends StatefulWidget {
  const PreviewSettingsPage({super.key});
  @override
  State<PreviewSettingsPage> createState() => _PreviewSettingsPageState();
}

class _PreviewSettingsPageState extends State<PreviewSettingsPage> {
  late final _gateway = TextEditingController(
    text: previewSettings.gateway ?? '',
  );
  String? _message;
  bool _saving = false;
  @override
  void dispose() {
    _gateway.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await previewSettings.setGateway(_gateway.text);
      if (mounted)
        setState(
          () => _message = previewSettings.gateway == null
              ? context.l10n.previewNoGateway
              : context.l10n.previewGatewaySaved,
        );
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.previewSettingsTitle)),
    body: ReadableWidth(
      child: ListenableBuilder(
        listenable: previewSettings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.previewNeverTitle),
              subtitle: Text(context.l10n.previewNeverSubtitle),
              value: previewSettings.never,
              onChanged: (value) async {
                try {
                  await previewSettings.setNever(value);
                } catch (e) {
                  if (mounted) setState(() => _message = '$e');
                }
              },
            ),
            const SizedBox(height: 24),
            Text(context.l10n.previewSettingsIpfsOnly),
            const SizedBox(height: 16),
            TextField(
              controller: _gateway,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.l10n.previewGatewayFieldLabel,
                helperText: context.l10n.previewGatewayFieldHelper,
              ),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.previewGatewayCheckInfo),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? context.l10n.previewCheckingGateway
                    : context.l10n.previewSaveGateway,
              ),
            ),
            if (_message != null) Text(_message!),
          ],
        ),
      ),
    ),
  );
}
