//! Payment requests: `bitcoin:` URIs (BIP-21) and plain addresses, as a QR code gives them.

use crate::network::BtcNetwork;
use crate::wallet::parse_address;

/// What a payment request asks for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PaymentRequest {
    pub address: String,
    /// The amount, in satoshi, if the request gives one.
    pub amount_sat: Option<u64>,
    pub label: Option<String>,
    pub message: Option<String>,
}

/// `text` as a payment request on `network`: `bitcoin:<address>[?amount=<BTC>&label=…]` or a
/// plain address. `None` if the address is not one of `network`, if the amount is not a
/// number of BTC with 8 decimals or fewer, or if a `req-` parameter that this wallet does
/// not know is there (BIP-21 says to refuse it).
pub fn parse_payment_request(text: &str, network: BtcNetwork) -> Option<PaymentRequest> {
    let text = text.trim();
    let (address, query) = match text.get(..8) {
        Some(scheme) if scheme.eq_ignore_ascii_case("bitcoin:") => {
            let rest = &text[8..];
            match rest.split_once('?') {
                Some((a, q)) => (a, Some(q)),
                None => (rest, None),
            }
        }
        _ => (text, None),
    };
    let address = parse_address(address, network).ok()?.to_string();
    let mut request = PaymentRequest {
        address,
        amount_sat: None,
        label: None,
        message: None,
    };
    for pair in query.unwrap_or("").split('&').filter(|p| !p.is_empty()) {
        let (key, value) = pair.split_once('=').unwrap_or((pair, ""));
        let value = percent_decode(value)?;
        match key {
            "amount" => request.amount_sat = Some(parse_btc(&value)?),
            "label" => request.label = Some(value),
            "message" => request.message = Some(value),
            k if k.starts_with("req-") => return None,
            _ => {}
        }
    }
    Some(request)
}

/// A `bitcoin:` URI for `address`, with the amount when it is not 0.
pub fn payment_uri(address: &str, amount_sat: u64) -> String {
    if amount_sat == 0 {
        return format!("bitcoin:{address}");
    }
    let whole = amount_sat / 100_000_000;
    let frac = format!("{:08}", amount_sat % 100_000_000);
    let frac = frac.trim_end_matches('0');
    if frac.is_empty() {
        format!("bitcoin:{address}?amount={whole}")
    } else {
        format!("bitcoin:{address}?amount={whole}.{frac}")
    }
}

/// `0.001` BTC as satoshi; no sign, no exponent, 8 decimals or fewer.
fn parse_btc(text: &str) -> Option<u64> {
    let (whole, frac) = text.split_once('.').unwrap_or((text, ""));
    if whole.is_empty() && frac.is_empty() {
        return None;
    }
    if !whole.bytes().all(|b| b.is_ascii_digit()) || !frac.bytes().all(|b| b.is_ascii_digit()) || frac.len() > 8 {
        return None;
    }
    let whole: u64 = if whole.is_empty() { 0 } else { whole.parse().ok()? };
    let frac: u64 = if frac.is_empty() { 0 } else { format!("{frac:0<8}").parse().ok()? };
    if whole > 21_000_000 {
        return None;
    }
    Some(whole * 100_000_000 + frac)
}

fn percent_decode(text: &str) -> Option<String> {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'%' => {
                let hex = text.get(i + 1..i + 3)?;
                out.push(u8::from_str_radix(hex, 16).ok()?);
                i += 3;
            }
            b => {
                out.push(b);
                i += 1;
            }
        }
    }
    String::from_utf8(out).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    const SIGNET: &str = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
    const MAINNET: &str = "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu";

    #[test]
    fn plain_address_and_uri() {
        let r = parse_payment_request(&format!(" {SIGNET} "), BtcNetwork::Signet).unwrap();
        assert_eq!(r.address, SIGNET);
        assert_eq!(r.amount_sat, None);
        let r = parse_payment_request(
            &format!("BITCOIN:{SIGNET}?amount=0.0015&label=Node%20deposit&message=hi&other=1"),
            BtcNetwork::Signet,
        )
        .unwrap();
        assert_eq!(r.amount_sat, Some(150_000));
        assert_eq!(r.label.as_deref(), Some("Node deposit"));
        assert_eq!(r.message.as_deref(), Some("hi"));
    }

    #[test]
    fn refused() {
        // Another network.
        assert!(parse_payment_request(MAINNET, BtcNetwork::Signet).is_none());
        assert!(parse_payment_request(&format!("bitcoin:{MAINNET}"), BtcNetwork::Signet).is_none());
        // Amounts that are not BTC with 8 decimals or fewer.
        for a in ["1e3", "-1", "0.000000001", "abc", ".", "21000001"] {
            assert!(parse_payment_request(&format!("bitcoin:{SIGNET}?amount={a}"), BtcNetwork::Signet).is_none(), "{a}");
        }
        // A required parameter that the wallet does not know.
        assert!(parse_payment_request(&format!("bitcoin:{SIGNET}?req-pop=1"), BtcNetwork::Signet).is_none());
        assert!(parse_payment_request("ergo:9f...", BtcNetwork::Signet).is_none());
    }

    #[test]
    fn uri_round_trip() {
        assert_eq!(payment_uri(SIGNET, 0), format!("bitcoin:{SIGNET}"));
        assert_eq!(payment_uri(SIGNET, 100_000_000), format!("bitcoin:{SIGNET}?amount=1"));
        let uri = payment_uri(SIGNET, 150_000);
        assert_eq!(uri, format!("bitcoin:{SIGNET}?amount=0.0015"));
        assert_eq!(parse_payment_request(&uri, BtcNetwork::Signet).unwrap().amount_sat, Some(150_000));
        assert_eq!(parse_payment_request(&payment_uri(SIGNET, 1), BtcNetwork::Signet).unwrap().amount_sat, Some(1));
    }
}
