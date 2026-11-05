/// Amounts of bitcoin: one BTC is 100,000,000 satoshi.
const satPerBtc = 100000000;

/// [sat] as BTC with 8 decimals, the trailing zeros cut to at least 2 decimals
/// (`0.0015`, `1.00`, `0.00000546`).
String formatBtc(int sat) {
  final negative = sat < 0;
  final abs = sat.abs();
  final whole = abs ~/ satPerBtc;
  var frac = (abs % satPerBtc).toString().padLeft(8, '0');
  while (frac.length > 2 && frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  return '${negative ? '-' : ''}$whole.$frac';
}

/// [sat] with a thin grouping: `12 345 sat`.
String formatSat(int sat) {
  final digits = sat.abs().toString();
  final out = StringBuffer(sat < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return '$out sat';
}

/// A BTC amount as the user types it (`0.001`, `0,001`, `.5`) in satoshi. Null if it is
/// not a number, has more than 8 decimals, or is more than 21 million BTC.
int? parseBtc(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty || !RegExp(r'^\d*\.?\d*$').hasMatch(t) || t == '.') return null;
  final parts = t.split('.');
  final whole = parts[0].isEmpty ? 0 : int.tryParse(parts[0]);
  final fracText = parts.length > 1 ? parts[1] : '';
  if (whole == null || fracText.length > 8) return null;
  final frac = fracText.isEmpty ? 0 : int.parse(fracText.padRight(8, '0'));
  if (whole > 21000000) return null;
  return whole * satPerBtc + frac;
}

/// The page of transaction [txid] on mempool.space for [network]; null on regtest, which no
/// public explorer has.
String? btcExplorerTx(String network, String txid) => switch (network) {
      'mainnet' => 'https://mempool.space/tx/$txid',
      'testnet' => 'https://mempool.space/testnet/tx/$txid',
      'signet' => 'https://mempool.space/signet/tx/$txid',
      _ => null,
    };

/// A fee rate in sat/vB as the screens show it: `5`, `5.5`.
String formatFeeRate(double r) => r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);

final _bech32 = RegExp(r'^(bc|tb|bcrt)1[02-9ac-hj-np-z]{8,87}$');
final _base58 = RegExp(r'^[123mn][1-9A-HJ-NP-Za-km-z]{25,34}$');

/// True if [value] has the form of a Bitcoin address of any network. A loose check for the
/// address book; a send checks the address on the wallet's network.
bool looksLikeBitcoinAddress(String value) {
  final v = value.trim();
  return _bech32.hasMatch(v.toLowerCase()) && (v == v.toLowerCase() || v == v.toUpperCase()) || _base58.hasMatch(v);
}
