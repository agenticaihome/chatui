import 'package:argus_wallet/bitcoin/bitcoin_settings.dart';
import 'package:argus_wallet/bitcoin/bitcoin_wallet_api.dart';
import 'package:argus_wallet/bridge/api/btc.dart';
import 'package:argus_wallet/bridge/api/celaut_btc_deposit.dart';
import 'package:argus_wallet/bridge/api/celaut_service.dart';
import 'package:flutter/widgets.dart';

/// A Bitcoin wallet for widget tests: a signet wallet with 0.0015 BTC, and a node that
/// takes BTC on signet ([FakeBitcoin.accepts]).
const fakeBtcAddress = 'tb1qcr8te4kr609gcawutmrza0j4xv80jy8zeqchgx';
const fakeBtcTxid = 'aa00000000000000000000000000000000000000000000000000000000000001';
const fakeBtcPeer = 'bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11bb11';

BtcWalletView _view({int confirmed = 150000, int pending = 0}) => BtcWalletView(
      network: 'signet',
      server: 'https://mempool.space/signet/api',
      receiveAddress: fakeBtcAddress,
      confirmedSat: BigInt.from(confirmed),
      pendingSat: BigInt.from(pending),
      immatureSat: BigInt.zero,
      tipHeight: 200,
    );

BtcPreparedView _prepared(int sat, {String replaces = ''}) => BtcPreparedView(
      id: BigInt.from(7),
      to: fakeBtcAddress,
      amountSat: BigInt.from(sat),
      feeSat: BigInt.from(282),
      feeRate: 2,
      changeSat: BigInt.from(1000),
      txid: fakeBtcTxid,
      replaces: replaces,
    );

/// A payment of the fake wallet that waits for a block: it can get a higher fee.
const fakeBtcWaiting = 'cc00000000000000000000000000000000000000000000000000000000000002';
const fakeBtcBumped = 'dd00000000000000000000000000000000000000000000000000000000000003';

const fakeDescriptors = BtcDescriptors(
  network: 'signet',
  receive: 'wpkh([73c5da0a/84h/1h/0h]tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39yBA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M/0/*)',
  change: 'wpkh([73c5da0a/84h/1h/0h]tpubDC8msFGeGuwnKG9Upg7DM2b4DaRqg3CUZa5g8v2SRQ6K4NSkxUgd7HsL2XVWbVm39yBA4LAxysQAm397zwQSQoQgewGiYZqrA9DsP4zbQ1M/1/*)',
);

class FakeBitcoin implements BitcoinWallet {
  FakeBitcoin({this.unlocks = true, this.accepts = true, this.confirmations = 2, this.unlocked = true});

  @override
  bool unlocked;

  /// What [watch] reads (the wallet is locked).
  int watchedSat = 90000;

  /// [sync] and [watch] fail with this, when set.
  Object? failWith;

  @override
  final settings = BitcoinSettings()..loaded = true;

  bool unlocks;
  bool consents = true;
  bool accepts;
  int confirmations;
  int statusConfirmations = 0;
  final calls = <String>[];
  final sentIds = <BigInt>[];
  final cancelled = <BigInt>[];
  var deposits = <BtcDepositSentView>[];

  @override
  Future<bool> unlock(BuildContext context) async {
    calls.add('unlock');
    return unlocks;
  }

  @override
  Future<bool> consent(BuildContext context) async {
    calls.add('consent');
    return consents;
  }

  @override
  Future<BtcWalletView> open() async {
    calls.add('open');
    return _view();
  }

  @override
  Future<BtcWalletView> sync() async {
    calls.add('sync');
    if (failWith != null) throw failWith!;
    return _view(pending: 5000);
  }

  @override
  Future<List<BtcTxView>> transactions() async => [
        BtcTxView(
          txid: fakeBtcTxid,
          netSat: 150000,
          feeSat: BigInt.zero,
          feeKnown: false,
          confirmations: 3,
          time: BigInt.from(1700000000),
        ),
      ];

  @override
  Future<BtcFeeRates> feeRates() async =>
      const BtcFeeRates(fast: 12, normal: 5.5, slow: 1, estimated: true);

  @override
  bool isAddress(String address) => address.startsWith('tb1');

  @override
  Future<BtcPreparedView> prepareSend(String to, int sat, {required bool sendAll, required double feeRate}) async {
    calls.add('prepare $sat $sendAll $feeRate');
    return _prepared(sendAll ? 149718 : sat);
  }

  @override
  Future<String> send(BtcPreparedView prepared) async {
    sentIds.add(prepared.id);
    return prepared.txid;
  }

  @override
  void cancel(BtcPreparedView prepared) => cancelled.add(prepared.id);

  @override
  Future<BtcDescriptors> descriptors() async {
    calls.add('descriptors');
    return fakeDescriptors;
  }

  @override
  Future<BtcWatchView> watch(BtcDescriptors descriptors) async {
    calls.add('watch ${descriptors.network}');
    if (failWith != null) throw failWith!;
    return BtcWatchView(wallet: _view(confirmed: watchedSat), transactions: await transactions());
  }

  @override
  Future<List<BtcAddressView>> addresses() async => [
        BtcAddressView(address: fakeBtcAddress, index: 0, change: false, used: true, sat: BigInt.from(150000), utxos: 1),
        BtcAddressView(
          address: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
          index: 1,
          change: false,
          used: false,
          sat: BigInt.zero,
          utxos: 0,
        ),
      ];

  @override
  Future<List<BtcUtxoView>> utxos() async => [
        BtcUtxoView(txid: fakeBtcTxid, vout: 0, sat: BigInt.from(150000), address: fakeBtcAddress, change: false, confirmations: 3),
      ];

  @override
  Future<BtcTxDetailView> transaction(String txid) async {
    calls.add('transaction $txid');
    final waiting = txid == fakeBtcWaiting;
    BtcTxPartView part(int sat, {bool mine = false, bool data = false, String? address}) => BtcTxPartView(
          address: address ?? (data ? '' : fakeBtcAddress),
          sat: BigInt.from(sat),
          satKnown: true,
          mine: mine,
          data: data,
        );
    return BtcTxDetailView(
      tx: BtcTxView(
        txid: txid,
        netSat: waiting ? -30282 : 150000,
        feeSat: BigInt.from(282),
        feeKnown: true,
        confirmations: waiting ? 0 : 3,
        time: BigInt.from(1700000000),
      ),
      inputs: [part(100000, mine: waiting)],
      outputs: [
        part(30000, address: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'),
        part(69718, mine: true),
        if (!waiting) part(0, data: true),
      ],
      vsize: BigInt.from(141),
      feeRate: 2,
      canBump: waiting,
    );
  }

  @override
  Future<BtcPreparedView> prepareBump(String txid, double feeRate) async {
    calls.add('bump $txid $feeRate');
    return BtcPreparedView(
      id: BigInt.from(9),
      to: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      amountSat: BigInt.from(30000),
      feeSat: BigInt.from(846),
      feeRate: feeRate,
      changeSat: BigInt.from(69154),
      txid: fakeBtcBumped,
      replaces: txid,
    );
  }

  @override
  BtcPaymentRequest? paymentRequest(String text) {
    final t = text.trim();
    final address = t.startsWith('bitcoin:') ? t.substring(8).split('?').first : t;
    if (!isAddress(address)) return null;
    final amount = RegExp(r'amount=([0-9.]+)').firstMatch(t)?.group(1);
    return BtcPaymentRequest(
      address: address,
      amountSat: BigInt.from(amount == null ? 0 : (double.parse(amount) * 100000000).round()),
      label: '',
      message: '',
    );
  }

  @override
  String paymentUri(String address, int sat) =>
      sat == 0 ? 'bitcoin:$address' : 'bitcoin:$address?amount=${(sat / 100000000).toString()}';

  @override
  Future<void> lock() async {
    calls.add('lock');
    unlocked = false;
  }

  @override
  Future<BtcDepositNodeView> depositNode(NodeAddress node) async {
    calls.add('node ${node.host}:${node.port}');
    return BtcDepositNodeView(
      peerId: fakeBtcPeer,
      networks: accepts ? ['signet'] : ['mainnet'],
      accepts: accepts,
      reason: accepts ? '' : 'the BTC payment contract of the node is on mainnet, not on signet',
      payToAddress: accepts ? fakeBtcAddress : '',
      muPerSat: accepts ? '7' : '',
      confirmations: confirmations,
      nodeSaysConfirmations: false,
      clientBalanceMu: '4500000',
    );
  }

  @override
  Future<BtcDepositPreparedView> prepareDeposit(NodeAddress node, int sat, double feeRate) async {
    calls.add('prepareDeposit $sat $feeRate');
    return BtcDepositPreparedView(
      depositId: 'd1',
      peerId: fakeBtcPeer,
      payToAddress: fakeBtcAddress,
      mu: '${sat * 7}',
      confirmations: confirmations,
      transaction: _prepared(sat),
    );
  }

  @override
  Future<String> sendDeposit(BtcDepositPreparedView prepared) async {
    calls.add('sendDeposit ${prepared.depositId}');
    deposits = [
      BtcDepositSentView(
        depositId: prepared.depositId,
        peerId: fakeBtcPeer,
        address: '127.0.0.1:18460',
        network: 'signet',
        sat: prepared.transaction.amountSat,
        mu: prepared.mu,
        txId: fakeBtcTxid,
        confirmations: confirmations,
        madeAt: 1,
      ),
    ];
    return fakeBtcTxid;
  }

  @override
  void cancelDeposit(BtcDepositPreparedView prepared) => calls.add('cancelDeposit');

  @override
  List<BtcDepositSentView> sentDeposits() => deposits;

  @override
  Future<BtcDepositStatusView> depositStatus(String depositId) async {
    calls.add('status');
    return BtcDepositStatusView(confirmations: statusConfirmations, needed: confirmations, known: true);
  }

  @override
  Future<BtcDepositDoneView> notifyDeposit(String depositId) async {
    calls.add('notify $depositId');
    deposits = [];
    return BtcDepositDoneView(
      depositId: depositId,
      txId: fakeBtcTxid,
      accepted: true,
      nodeMessage: null,
      clientBalanceMu: '4570000',
    );
  }

  @override
  Future<void> forgetDeposit(String depositId) async => calls.add('forget $depositId');
}
