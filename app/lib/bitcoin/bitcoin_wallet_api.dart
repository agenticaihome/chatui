import 'package:flutter/widgets.dart';

import '../bridge/api/btc.dart';
import '../bridge/api/celaut_btc_deposit.dart';
import '../bridge/api/celaut_service.dart';
import '../celaut/payers.dart';
import '../services/wallet_service.dart';
import 'bitcoin_settings.dart';

/// What the Bitcoin screens need from the app. The app uses [AppBitcoinWallet]; tests give
/// their own.
///
/// The Bitcoin wallet is the open wallet's seed on BIP-84 (`wallet_btc::keys`), so it is
/// there only while the wallet is open ([open] unlocks it first).
abstract class BitcoinWallet {
  BitcoinSettings get settings;

  /// Unlock the wallet if it is locked. False if the app has no wallet or the user did not
  /// open it.
  Future<bool> unlock(BuildContext context);

  /// The consent of the user before a send: the fingerprint or the screen lock, also when
  /// the wallet is open (`docs/celaut/ui.md`, section 1).
  Future<bool> consent(BuildContext context);

  /// Open the Bitcoin wallet on the network and server of [settings].
  Future<BtcWalletView> open();

  Future<BtcWalletView> sync();

  Future<List<BtcTxView>> transactions();

  Future<BtcFeeRates> feeRates();

  bool isAddress(String address);

  Future<BtcPreparedView> prepareSend(String to, int sat, {required bool sendAll, required double feeRate});

  Future<String> send(BtcPreparedView prepared);

  void cancel(BtcPreparedView prepared);

  // Deposits to a node in BTC.

  Future<BtcDepositNodeView> depositNode(NodeAddress node);

  Future<BtcDepositPreparedView> prepareDeposit(NodeAddress node, int sat, double feeRate);

  Future<String> sendDeposit(BtcDepositPreparedView prepared);

  void cancelDeposit(BtcDepositPreparedView prepared);

  List<BtcDepositSentView> sentDeposits();

  Future<BtcDepositStatusView> depositStatus(String depositId);

  Future<BtcDepositDoneView> notifyDeposit(String depositId);

  Future<void> forgetDeposit(String depositId);
}

class AppBitcoinWallet implements BitcoinWallet {
  const AppBitcoinWallet({this.wallets = const AppFullWallets()});

  final FullWallets wallets;

  @override
  BitcoinSettings get settings => bitcoinSettings;

  BigInt get _handle {
    final id = walletService.handleId;
    if (id == null) throw const BtcError(kind: BtcErrorKind.locked, message: 'the wallet is locked');
    return id;
  }

  @override
  Future<bool> unlock(BuildContext context) => ensureOpenFullWallet(context, wallets);

  @override
  Future<bool> consent(BuildContext context) async {
    final payers = await wallets.payers();
    if (payers.isEmpty || !context.mounted) return false;
    return wallets.unlock(context, payers.first);
  }

  @override
  Future<BtcWalletView> open() async {
    if (!settings.loaded) await settings.load();
    return btcOpen(handleId: _handle, network: settings.network.name, server: settings.server);
  }

  @override
  Future<BtcWalletView> sync() => btcSync(handleId: _handle);

  @override
  Future<List<BtcTxView>> transactions() => btcTransactions(handleId: _handle);

  @override
  Future<BtcFeeRates> feeRates() => btcFeeRates(handleId: _handle);

  @override
  bool isAddress(String address) => btcIsAddress(network: settings.network.name, address: address);

  @override
  Future<BtcPreparedView> prepareSend(String to, int sat, {required bool sendAll, required double feeRate}) =>
      btcPrepareSend(
        handleId: _handle,
        to: to,
        amountSat: BigInt.from(sat),
        sendAll: sendAll,
        feeRate: feeRate,
      );

  @override
  Future<String> send(BtcPreparedView prepared) => btcSend(handleId: _handle, preparedId: prepared.id);

  @override
  void cancel(BtcPreparedView prepared) => btcCancel(preparedId: prepared.id);

  @override
  Future<BtcDepositNodeView> depositNode(NodeAddress node) async {
    if (!settings.loaded) await settings.load();
    return celautBtcDepositNode(node: node, network: settings.network.name);
  }

  @override
  Future<BtcDepositPreparedView> prepareDeposit(NodeAddress node, int sat, double feeRate) =>
      celautBtcDepositPrepare(handleId: _handle, node: node, sat: BigInt.from(sat), feeRate: feeRate);

  @override
  Future<String> sendDeposit(BtcDepositPreparedView prepared) => celautBtcDepositSend(
        handleId: _handle,
        depositId: prepared.depositId,
        preparedId: prepared.transaction.id,
      );

  @override
  void cancelDeposit(BtcDepositPreparedView prepared) {
    celautBtcDepositCancel(depositId: prepared.depositId, preparedId: prepared.transaction.id).ignore();
  }

  @override
  List<BtcDepositSentView> sentDeposits() => celautBtcSentDeposits();

  @override
  Future<BtcDepositStatusView> depositStatus(String depositId) => celautBtcDepositStatus(depositId: depositId);

  @override
  Future<BtcDepositDoneView> notifyDeposit(String depositId) => celautBtcDepositNotify(depositId: depositId);

  @override
  Future<void> forgetDeposit(String depositId) => celautBtcDepositForget(depositId: depositId);
}
