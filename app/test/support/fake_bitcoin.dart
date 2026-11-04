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

BtcPreparedView _prepared(int sat) => BtcPreparedView(
      id: BigInt.from(7),
      to: fakeBtcAddress,
      amountSat: BigInt.from(sat),
      feeSat: BigInt.from(282),
      feeRate: 2,
      changeSat: BigInt.from(1000),
      txid: fakeBtcTxid,
    );

class FakeBitcoin implements BitcoinWallet {
  FakeBitcoin({this.unlocks = true, this.accepts = true, this.confirmations = 2});

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
    return fakeBtcTxid;
  }

  @override
  void cancel(BtcPreparedView prepared) => cancelled.add(prepared.id);

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
