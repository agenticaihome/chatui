import 'layout.dart';
import 'widgets/error_sheet.dart';
import 'package:flutter/material.dart';

import '../bridge/argus_error.dart';
import '../l10n/l10n.dart';
import '../services/privacy_service.dart';
import '../services/secure_storage.dart';
import '../services/wallet_service.dart';
import '../theme/argus_theme.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  String? _mnemonic;
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _revealed = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    armSecureFlag(context);
  }

  @override
  void dispose() {
    privacyService.applyScreenshotPolicy();
    _confirmCtrl.clear();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final phrase = await walletService.generateMnemonic(strength: 160);
      setState(() {
        _mnemonic = phrase;
        _revealed = false;
        _confirmCtrl.clear();
      });
    } on ArgusException catch (e) {
      showErrorSheet(context, code: e.code, message: e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toConfirm() {
    if (_mnemonic == null) return;
    setState(() => _step = 1);
  }

  Future<void> _confirmAndFinish() async {
    final phrase = _mnemonic;
    if (phrase == null || !mnemonicWordsEqual(_confirmCtrl.text, phrase)) {
      _snack(context.l10n.createPhraseMismatch);
      return;
    }
    await _finish();
  }

  Future<void> _skipConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.createSkipTitle),
        content: Text(
          ctx.l10n.createSkipBody,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.createSkip)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _confirmCtrl.clear();
    await _finish();
  }

  Future<String?> _finish() async {
    final phrase = _mnemonic;
    if (phrase == null) return null;
    setState(() => _busy = true);
    try {
      final walletId = await walletService.provisionWallet(
        phrase: phrase,
        passphrase: '',
        // One wallet: the app shows no name, and the core keeps its default.
        name: '',
      );
      if (!mounted) return null;
      Navigator.pop(context, walletId);
    } on ArgusException catch (e) {
      showErrorSheet(context, code: e.code, message: e.message);
    } on SecureStorageException catch (e) {
      showErrorSheet(context, message: e.message);
    } catch (e) {
      showErrorSheet(context, title: context.l10n.createFailedTitle, message: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return null;
  }

  void _snack(String msg) {
    if (mounted) showErrorSheet(context, message: msg);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) setState(() => _step -= 1);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step -= 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: ReadableWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            StepDots(total: 2, index: _step),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: switch (_step) {
                1 => _confirmStep(),
                _ => _backupStep(),
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _backupStep() {
    final words = _mnemonic?.split(RegExp(r'\s+')) ?? const <String>[];
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.createWriteDownTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          context.l10n.createWriteDownBody,
        ),
        const SizedBox(height: 20),
        if (_mnemonic == null)
          FilledButton(
            onPressed: _busy ? null : _generate,
            child: Text(context.l10n.createGenerate),
          )
        else ...[
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _revealed
                  ? Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < words.length; i++)
                          SizedBox(
                            width: 140,
                            child: Text(
                              '${i + 1}.  ${words[i]}',
                              style: monoStyle(context, size: 14),
                            ),
                          ),
                      ],
                    )
                  : Text(
                      '••••  ••••  ••••  ••••',
                      style: monoStyle(context, size: 16),
                    ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _revealed = !_revealed),
              child: Text(_revealed ? context.l10n.createHide : context.l10n.createReveal),
            ),
          ),
          FilledButton(
            onPressed: _toConfirm,
            child: Text(context.l10n.createWroteDown),
          ),
        ],
      ],
    );
  }

  Widget _confirmStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.createConfirmTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(context.l10n.createConfirmBody),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmCtrl,
          decoration: InputDecoration(labelText: context.l10n.createPhraseLabel),
          minLines: 4,
          maxLines: 6,
          enableSuggestions: false,
          autocorrect: false,
          enableIMEPersonalizedLearning: false,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _confirmAndFinish,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.createTitle),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('create-skip-confirm'),
          onPressed: _busy ? null : _skipConfirm,
          child: Text(context.l10n.createSkipCheck),
        ),
      ],
    );
  }
}

Future<bool> confirmReplaceExistingWallet(BuildContext context) async {
  if (!await SecureStorageService.hasEncryptedSeed()) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.createReplaceTitle),
      content: Text(
        ctx.l10n.createReplaceBody,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.createReplace)),
      ],
    ),
  );
  return ok == true;
}

Future<void> armSecureFlag(BuildContext context) async {
  try {
    final ok = await SecureStorageService.setSecureFlag(true);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createScreenshotBlockUnavailable)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createScreenshotBlockUnavailable)),
      );
    }
  }
}
