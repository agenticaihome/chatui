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

  /// The wallet is open (its seed is in memory): the Bitcoin wallet can open and sign.
  bool get unlocked;

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

  // Parity with the Ergo wallet (issue #103).

  /// The public descriptors of the open wallet, kept to read it while it is locked.
  Future<BtcDescriptors> descriptors();

  /// Read the figures of [descriptors] with no key (the wallet is locked).
  Future<BtcWatchView> watch(BtcDescriptors descriptors);

  Future<List<BtcAddressView>> addresses();

  Future<List<BtcUtxoView>> utxos();

  Future<BtcTxDetailView> transaction(String txid);

  /// The unconfirmed payment [txid] again, at the higher [feeRate] (RBF).
  Future<BtcPreparedView> prepareBump(String txid, double feeRate);

  /// A scanned QR code as a payment request on the network of [settings], or null.
  BtcPaymentRequest? paymentRequest(String text);

  /// The `bitcoin:` URI of a request for [sat] (0: any amount) to [address].
  String paymentUri(String address, int sat);

  /// Lock the wallet (the Ergo wallet and the Bitcoin wallet: they are the same words).
  Future<void> lock();

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

  @override
  bool get unlocked => walletService.handleId != null;

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
  Future<BtcDescriptors> descriptors() => btcDescriptors(handleId: _handle);

  @override
  Future<BtcWatchView> watch(BtcDescriptors descriptors) async {
    if (!settings.loaded) await settings.load();
    final network = BtcNetworkName.parse(descriptors.network) ?? settings.network;
    return btcWatch(descriptors: descriptors, server: settings.serverOf(network));
  }

  @override
  Future<List<BtcAddressView>> addresses() => btcAddresses(handleId: _handle);

  @override
  Future<List<BtcUtxoView>> utxos() => btcUtxos(handleId: _handle);

  @override
  Future<BtcTxDetailView> transaction(String txid) => btcTxDetail(handleId: _handle, txid: txid);

  @override
  Future<BtcPreparedView> prepareBump(String txid, double feeRate) =>
      btcPrepareBump(handleId: _handle, txid: txid, feeRate: feeRate);

  @override
  BtcPaymentRequest? paymentRequest(String text) =>
      btcParsePaymentRequest(network: settings.network.name, text: text);

  @override
  String paymentUri(String address, int sat) => btcPaymentUri(address: address, amountSat: BigInt.from(sat));

  @override
  Future<void> lock() => walletService.lock();

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
