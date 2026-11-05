import 'package:flutter/widgets.dart';

import '../ui/home/home_models.dart';

/// The coins of the app's wallet. The wallet has one recovery phrase; each coin derives its
/// own keys from it (Ergo: EIP-3, Bitcoin: BIP-84).
enum Coin {
  ergo(unit: 'ERG', decimals: 9),
  bitcoin(unit: 'BTC', decimals: 8);

  const Coin({required this.unit, required this.decimals});

  /// The unit that amounts are shown in.
  final String unit;

  /// The decimals of [unit]: an amount is an integer of the smallest unit (nanoERG, satoshi).
  final int decimals;
}

/// What a wallet of a coin can do. Each [CoinWallet] says which features it has; the
/// overview shows the same structure for each, and a test compares the sets
/// ([coinOnlyFeatures]).
enum WalletFeature {
  /// The balance, in the coin's unit.
  balance,

  /// What is not confirmed yet, apart from the balance.
  pending,

  /// The last figures while the wallet is locked, and a refresh with no key.
  lockedFigures,

  /// The figures can be hidden (the eye), with the app's privacy setting.
  hideBalances,

  /// Pull to refresh: read the chain again.
  refresh,

  /// An address to receive, as text and as a QR code.
  receive,

  /// A request for an amount, in the QR code of the address.
  receiveAmount,

  /// Copy and share the address.
  shareAddress,

  /// A label on an address of the wallet.
  addressLabels,

  /// Send to an address.
  send,

  /// Send everything that the wallet can spend, less the fee.
  sendAll,

  /// Scan a QR code (an address or a payment request) to send.
  scanToSend,

  /// Pick the recipient from the address book, and save a new one to it.
  addressBook,

  /// A choice of the fee.
  feeChoice,

  /// The confirmation sheet, then the fingerprint or the screen lock of the phone.
  confirmSend,

  /// The list of transactions.
  history,

  /// A transaction with its amounts, fee and confirmations, and its ID to copy.
  transactionDetail,

  /// The transaction on a block explorer.
  explorerLink,

  /// Every address that the wallet showed or used, with what it holds.
  addresses,

  /// The unspent outputs of the wallet.
  utxos,

  /// A deposit to a Celaut node.
  depositToNode,

  /// The recovery phrase of the wallet restores the coin.
  backupRestore,

  /// Lock the wallet.
  lock,

  /// The network and the server that the wallet reads the chain from.
  networkSettings,

  // Ergo only (see [coinOnlyFeatures]).

  /// Tokens on the wallet's boxes.
  tokens,

  /// ErgoPay signing requests.
  ergoPay,

  /// The UTXO tools: consolidate, split, storage rent.
  utxoTools,

  /// The value of the wallet in a fiat currency.
  fiatValue,

  /// A notice when a payment comes in.
  incomingNotice,

  // Bitcoin only.

  /// Send a payment that waits again with a higher fee (RBF, BIP-125).
  feeBump,
}

/// The features that only one coin has, and why the other one does not have them. Each
/// entry is a decision; the parity test fails if a coin gets or loses a feature that is
/// not here.
const coinOnlyFeatures = <Coin, Map<WalletFeature, String>>{
  Coin.ergo: {
    WalletFeature.tokens: 'Bitcoin has no tokens on its outputs (Ordinals and Runes are other protocols).',
    WalletFeature.ergoPay: 'ErgoPay is an Ergo protocol. On Bitcoin a QR payment request (BIP-21) does this.',
    WalletFeature.utxoTools:
        'Consolidate and split are for Ergo boxes and storage rent. Bitcoin has no storage rent; the list of outputs is there.',
    WalletFeature.fiatValue: 'The app has no BTC price source yet, and coins of a test network have no price.',
    WalletFeature.incomingNotice: 'A notice needs a poll of the Esplora server in the background.',
  },
  Coin.bitcoin: {
    WalletFeature.feeBump: 'Ergo has no replace-by-fee: a transaction stays as it was sent.',
  },
};

/// One figure of a coin: what the overview shows for it, the same fields for each coin.
@immutable
class CoinFigures {
  const CoinFigures({
    this.total,
    this.pending,
    this.loading = false,
    this.asOf,
    this.testNetwork,
    this.recent = const [],
    this.note,
  });

  /// Nothing is known yet.
  static const unknown = CoinFigures();

  /// Everything the wallet holds, in the smallest unit of the coin; null while unknown.
  final int? total;

  /// What is not confirmed yet, in the smallest unit of the coin.
  final PendingBalance? pending;

  /// Being read now.
  final bool loading;

  /// How old the figures are ("3h ago"), when they are not live.
  final String? asOf;

  /// The network, when it is a test network (its coins have no value).
  final String? testNetwork;

  /// The latest transactions, the newest first.
  final List<ActivityRowData> recent;

  /// One line about the wallet, e.g. why there are no figures.
  final String? note;
}

/// The actions that the overview offers for each coin, in this order.
enum CoinAction { send, receive, details }

/// A wallet of one coin, as the overview and the shared widgets use it. The app has one for
/// Ergo (`ErgoCoinWallet`) and one for Bitcoin (`BitcoinCoinWallet`); a new coin is a new
/// implementation of this class, with its own screens behind [act].
abstract class CoinWallet implements Listenable {
  Coin get coin;

  /// The name of the coin for the user ("Ergo", "Bitcoin").
  String get name;

  Set<WalletFeature> get features;

  CoinFigures get figures;

  /// Read the figures again. A locked wallet reads them with no key, if it can.
  Future<void> refresh();

  /// Do [action] for this coin. The wallet asks for the unlock first when the action
  /// needs the key.
  Future<void> act(BuildContext context, CoinAction action);

  /// Open the transaction [id] of [CoinFigures.recent].
  Future<void> openActivity(BuildContext context, String id);
}

/// The coins in the order of the overview.
List<CoinWallet> inCoinOrder(Iterable<CoinWallet> wallets) =>
    [...wallets]..sort((a, b) => a.coin.index.compareTo(b.coin.index));
