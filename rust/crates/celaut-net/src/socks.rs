//! A small SOCKS5 client and server (RFC 1928, and RFC 1929 for the user name and the
//! password). Only the command CONNECT, and no UDP.

use std::future::Future;
use std::io;
use std::net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr};
use std::sync::Arc;
use std::time::Duration;

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

use crate::{BoxStream, Socks5};

const VERSION: u8 = 5;
const METHOD_NONE: u8 = 0x00;
const METHOD_PASSWORD: u8 = 0x02;
const METHOD_REFUSED: u8 = 0xff;
const CMD_CONNECT: u8 = 0x01;
const ATYP_IPV4: u8 = 0x01;
const ATYP_DOMAIN: u8 = 0x03;
const ATYP_IPV6: u8 = 0x04;

const REP_OK: u8 = 0x00;
const REP_FAILURE: u8 = 0x01;
const REP_UNREACHABLE: u8 = 0x04;
const REP_REFUSED: u8 = 0x05;
const REP_COMMAND: u8 = 0x07;
const REP_ADDRESS: u8 = 0x08;

/// A limit for the setup of a connection through a proxy, the same for both sides.
const SETUP_TIMEOUT: Duration = Duration::from_secs(60);

fn invalid(text: impl Into<String>) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, text.into())
}

fn reply_text(code: u8) -> &'static str {
    match code {
        0x01 => "general failure",
        0x02 => "not allowed by the rules of the proxy",
        0x03 => "network unreachable",
        0x04 => "host unreachable",
        0x05 => "connection refused",
        0x06 => "TTL expired",
        0x07 => "command not supported",
        0x08 => "address type not supported",
        _ => "unknown reply",
    }
}

/// Write the address of a request or a reply: the type, the address and the port.
fn put_address(out: &mut Vec<u8>, host: &str, port: u16) -> io::Result<()> {
    match host.parse::<IpAddr>() {
        Ok(IpAddr::V4(ip)) => {
            out.push(ATYP_IPV4);
            out.extend_from_slice(&ip.octets());
        }
        Ok(IpAddr::V6(ip)) => {
            out.push(ATYP_IPV6);
            out.extend_from_slice(&ip.octets());
        }
        Err(_) => {
            let name = host.as_bytes();
            if name.is_empty() || name.len() > 255 {
                return Err(invalid("a host name has 1 to 255 bytes"));
            }
            out.push(ATYP_DOMAIN);
            out.push(name.len() as u8);
            out.extend_from_slice(name);
        }
    }
    out.extend_from_slice(&port.to_be_bytes());
    Ok(())
}

/// Read an address and a port after the address type.
async fn read_address(stream: &mut TcpStream, atyp: u8) -> io::Result<(String, u16)> {
    let host = match atyp {
        ATYP_IPV4 => {
            let mut b = [0u8; 4];
            stream.read_exact(&mut b).await?;
            Ipv4Addr::from(b).to_string()
        }
        ATYP_IPV6 => {
            let mut b = [0u8; 16];
            stream.read_exact(&mut b).await?;
            Ipv6Addr::from(b).to_string()
        }
        ATYP_DOMAIN => {
            let len = stream.read_u8().await? as usize;
            let mut b = vec![0u8; len];
            stream.read_exact(&mut b).await?;
            String::from_utf8(b).map_err(|_| invalid("a host name is not UTF-8"))?
        }
        other => return Err(invalid(format!("address type {other} is not known"))),
    };
    let port = stream.read_u16().await?;
    Ok((host, port))
}

/// Connect to `host:port` through `proxy`. `host` is a name or an IP literal. The name is
/// not looked up here.
pub async fn connect(proxy: &Socks5, host: &str, port: u16) -> io::Result<TcpStream> {
    tokio::time::timeout(SETUP_TIMEOUT, client_setup(proxy, host, port))
        .await
        .map_err(|_| io::Error::new(io::ErrorKind::TimedOut, "the SOCKS5 proxy did not answer"))?
}

async fn client_setup(proxy: &Socks5, host: &str, port: u16) -> io::Result<TcpStream> {
    let mut stream = TcpStream::connect(proxy.addr).await?;
    stream.set_nodelay(true)?;

    let methods: &[u8] = if proxy.auth.is_some() {
        &[METHOD_PASSWORD, METHOD_NONE]
    } else {
        &[METHOD_NONE]
    };
    let mut hello = vec![VERSION, methods.len() as u8];
    hello.extend_from_slice(methods);
    stream.write_all(&hello).await?;
    let mut choice = [0u8; 2];
    stream.read_exact(&mut choice).await?;
    if choice[0] != VERSION {
        return Err(invalid("the proxy does not speak SOCKS5"));
    }
    match choice[1] {
        METHOD_NONE => {}
        METHOD_PASSWORD => {
            let (user, password) = proxy
                .auth
                .as_ref()
                .ok_or_else(|| invalid("the proxy asks for a password that was not given"))?;
            if user.len() > 255 || password.len() > 255 {
                return Err(invalid("the user name and the password have 255 bytes or less"));
            }
            let mut auth = vec![1, user.len() as u8];
            auth.extend_from_slice(user.as_bytes());
            auth.push(password.len() as u8);
            auth.extend_from_slice(password.as_bytes());
            stream.write_all(&auth).await?;
            let mut status = [0u8; 2];
            stream.read_exact(&mut status).await?;
            if status[1] != 0 {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    "the proxy refused the user name or the password",
                ));
            }
        }
        METHOD_REFUSED => {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "the proxy accepts none of the methods that this client offers",
            ))
        }
        other => return Err(invalid(format!("the proxy chose the method {other}"))),
    }

    let mut request = vec![VERSION, CMD_CONNECT, 0];
    put_address(&mut request, host, port)?;
    stream.write_all(&request).await?;
    let mut head = [0u8; 4];
    stream.read_exact(&mut head).await?;
    if head[0] != VERSION {
        return Err(invalid("the proxy does not speak SOCKS5"));
    }
    if head[1] != REP_OK {
        let kind = match head[1] {
            REP_REFUSED => io::ErrorKind::ConnectionRefused,
            _ => io::ErrorKind::Other,
        };
        return Err(io::Error::new(
            kind,
            format!("the proxy could not connect: {}", reply_text(head[1])),
        ));
    }
    // The address that the proxy bound is not used, but it must be read.
    read_address(&mut stream, head[3]).await?;
    Ok(stream)
}

/// What a SOCKS5 server connects to when a client asks for `host:port`.
pub trait Dialer: Send + Sync + 'static {
    fn dial(
        &self,
        host: String,
        port: u16,
    ) -> impl Future<Output = io::Result<BoxStream>> + Send;
}

/// Run a SOCKS5 server on `listener` that needs the user name and the password in `auth`
/// and connects with `dialer`. It runs until the task ends. A client with a wrong user
/// name or password gets nothing.
pub async fn serve<D: Dialer>(listener: TcpListener, auth: (String, String), dialer: Arc<D>) {
    let auth = Arc::new(auth);
    loop {
        let Ok((stream, _)) = listener.accept().await else {
            return;
        };
        let (auth, dialer) = (auth.clone(), dialer.clone());
        tokio::spawn(async move {
            let _ = session(stream, &auth, dialer.as_ref()).await;
        });
    }
}

async fn session<D: Dialer>(
    mut stream: TcpStream,
    auth: &(String, String),
    dialer: &D,
) -> io::Result<()> {
    let target = tokio::time::timeout(SETUP_TIMEOUT, server_setup(&mut stream, auth))
        .await
        .map_err(|_| io::Error::new(io::ErrorKind::TimedOut, "the client was too slow"))??;
    let (host, port) = target;
    match dialer.dial(host, port).await {
        Ok(mut remote) => {
            reply(&mut stream, REP_OK).await?;
            let _ = tokio::io::copy_bidirectional(&mut stream, &mut remote).await;
            Ok(())
        }
        Err(e) => {
            let code = match e.kind() {
                io::ErrorKind::ConnectionRefused => REP_REFUSED,
                io::ErrorKind::HostUnreachable | io::ErrorKind::NetworkUnreachable => {
                    REP_UNREACHABLE
                }
                _ => REP_FAILURE,
            };
            reply(&mut stream, code).await?;
            Err(e)
        }
    }
}

/// The greeting, the password and the request. Gives the host and the port to connect to.
async fn server_setup(
    stream: &mut TcpStream,
    auth: &(String, String),
) -> io::Result<(String, u16)> {
    let mut head = [0u8; 2];
    stream.read_exact(&mut head).await?;
    if head[0] != VERSION {
        return Err(invalid("the client does not speak SOCKS5"));
    }
    let mut methods = vec![0u8; head[1] as usize];
    stream.read_exact(&mut methods).await?;
    if !methods.contains(&METHOD_PASSWORD) {
        stream.write_all(&[VERSION, METHOD_REFUSED]).await?;
        return Err(invalid("the client offers no password"));
    }
    stream.write_all(&[VERSION, METHOD_PASSWORD]).await?;

    let version = stream.read_u8().await?;
    let user_len = stream.read_u8().await? as usize;
    let mut user = vec![0u8; user_len];
    stream.read_exact(&mut user).await?;
    let password_len = stream.read_u8().await? as usize;
    let mut password = vec![0u8; password_len];
    stream.read_exact(&mut password).await?;
    let good = version == 1 && same(&user, auth.0.as_bytes()) & same(&password, auth.1.as_bytes());
    stream.write_all(&[1, if good { 0 } else { 1 }]).await?;
    if !good {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "a wrong user name or password",
        ));
    }

    let mut request = [0u8; 4];
    stream.read_exact(&mut request).await?;
    if request[0] != VERSION {
        return Err(invalid("the client does not speak SOCKS5"));
    }
    if request[1] != CMD_CONNECT {
        reply(stream, REP_COMMAND).await?;
        return Err(invalid("only CONNECT is supported"));
    }
    match read_address(stream, request[3]).await {
        Ok(target) => Ok(target),
        Err(e) => {
            reply(stream, REP_ADDRESS).await?;
            Err(e)
        }
    }
}

/// Compare two byte strings without stopping at the first difference.
fn same(a: &[u8], b: &[u8]) -> bool {
    let mut diff = (a.len() ^ b.len()) as u8;
    for (x, y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

async fn reply(stream: &mut TcpStream, code: u8) -> io::Result<()> {
    let mut out = vec![VERSION, code, 0];
    put_address(&mut out, "0.0.0.0", 0)?;
    stream.write_all(&out).await
}

/// The address that a listener on the loopback got, for the tests and for the owner of a
/// proxy.
pub async fn listen_loopback() -> io::Result<(TcpListener, SocketAddr)> {
    let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, 0)).await?;
    let addr = listener.local_addr()?;
    Ok((listener, addr))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::route::{connect as route_connect, set_route, Route};

    /// A dialer that connects to what the client asked for, and records it.
    struct Plain(std::sync::Mutex<Vec<(String, u16)>>);

    impl Dialer for Plain {
        async fn dial(&self, host: String, port: u16) -> io::Result<BoxStream> {
            self.0.lock().unwrap().push((host.clone(), port));
            let tcp = TcpStream::connect((host.as_str(), port)).await?;
            Ok(Box::new(tcp))
        }
    }

    /// A server that echoes the bytes of one connection.
    async fn echo() -> SocketAddr {
        let (listener, addr) = listen_loopback().await.unwrap();
        tokio::spawn(async move {
            while let Ok((mut s, _)) = listener.accept().await {
                tokio::spawn(async move {
                    let (mut r, mut w) = s.split();
                    let _ = tokio::io::copy(&mut r, &mut w).await;
                });
            }
        });
        addr
    }

    async fn proxy(dialer: Arc<Plain>) -> Socks5 {
        let (listener, addr) = listen_loopback().await.unwrap();
        tokio::spawn(serve(listener, ("user".into(), "secret".into()), dialer));
        Socks5 {
            addr,
            auth: Some(("user".into(), "secret".into())),
        }
    }

    #[tokio::test]
    async fn a_client_reaches_a_server_through_the_proxy() {
        let dialer = Arc::new(Plain(Default::default()));
        let proxy = proxy(dialer.clone()).await;
        let target = echo().await;
        let mut stream = connect(&proxy, "127.0.0.1", target.port()).await.unwrap();
        stream.write_all(b"hello").await.unwrap();
        let mut back = [0u8; 5];
        stream.read_exact(&mut back).await.unwrap();
        assert_eq!(&back, b"hello");
        assert_eq!(
            dialer.0.lock().unwrap().as_slice(),
            [("127.0.0.1".to_string(), target.port())]
        );
    }

    #[tokio::test]
    async fn a_host_name_goes_to_the_proxy_and_is_not_looked_up_here() {
        let dialer = Arc::new(Plain(Default::default()));
        let proxy = proxy(dialer.clone()).await;
        let target = echo().await;
        // "localhost" is a name: the proxy gets it as text.
        let mut stream = connect(&proxy, "localhost", target.port()).await.unwrap();
        stream.write_all(b"x").await.unwrap();
        let mut back = [0u8; 1];
        stream.read_exact(&mut back).await.unwrap();
        assert_eq!(dialer.0.lock().unwrap()[0].0, "localhost");
    }

    #[tokio::test]
    async fn an_ipv6_literal_is_sent_as_an_address() {
        let mut out = Vec::new();
        put_address(&mut out, "::1", 80).unwrap();
        assert_eq!(out[0], ATYP_IPV6);
        assert_eq!(out.len(), 1 + 16 + 2);
        let mut out = Vec::new();
        put_address(&mut out, "node.example", 53460).unwrap();
        assert_eq!(&out[..2], &[ATYP_DOMAIN, 12]);
        assert!(put_address(&mut Vec::new(), "", 1).is_err());
        assert!(put_address(&mut Vec::new(), &"a".repeat(256), 1).is_err());
    }

    #[tokio::test]
    async fn a_wrong_password_is_refused_and_nothing_is_dialed() {
        let dialer = Arc::new(Plain(Default::default()));
        let mut proxy = proxy(dialer.clone()).await;
        proxy.auth = Some(("user".into(), "wrong".into()));
        let target = echo().await;
        let error = connect(&proxy, "127.0.0.1", target.port()).await.unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(dialer.0.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn a_client_with_no_password_is_refused() {
        let dialer = Arc::new(Plain(Default::default()));
        let mut proxy = proxy(dialer.clone()).await;
        proxy.auth = None;
        let error = connect(&proxy, "127.0.0.1", 9).await.unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(dialer.0.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn a_refused_connection_is_a_refusal_for_the_client() {
        let dialer = Arc::new(Plain(Default::default()));
        let proxy = proxy(dialer).await;
        // Nothing listens on this port: take a free one and close it.
        let (listener, addr) = listen_loopback().await.unwrap();
        drop(listener);
        let error = connect(&proxy, "127.0.0.1", addr.port()).await.unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::ConnectionRefused);
    }

    #[tokio::test]
    async fn a_client_that_is_not_socks_gets_an_error() {
        let (listener, addr) = listen_loopback().await.unwrap();
        tokio::spawn(async move {
            let (mut s, _) = listener.accept().await.unwrap();
            let _ = s.write_all(b"HTTP/1.1 400 Bad Request\r\n\r\n").await;
        });
        let proxy = Socks5 { addr, auth: None };
        assert!(connect(&proxy, "example.org", 80).await.is_err());
    }

    #[test]
    fn onion_names() {
        use crate::route::is_onion;
        assert!(is_onion("abc.onion"));
        assert!(is_onion("ABC.ONION."));
        assert!(!is_onion("onion"));
        assert!(!is_onion("onion.example.org"));
        assert!(!is_onion("203.0.113.7"));
    }

    #[test]
    fn the_password_is_compared_in_full() {
        assert!(same(b"abc", b"abc"));
        assert!(!same(b"abc", b"abd"));
        assert!(!same(b"abc", b"ab"));
        assert!(!same(b"", b"a"));
    }

    #[tokio::test]
    async fn the_route_decides_how_connect_works() {
        let target = echo().await;
        set_route(Route::Direct);
        let mut direct = route_connect("127.0.0.1", target.port()).await.unwrap();
        direct.write_all(b"d").await.unwrap();
        let mut b = [0u8; 1];
        direct.read_exact(&mut b).await.unwrap();
        // An onion name never goes to the resolver of the system.
        let error = route_connect("abc.onion", 1).await.err().unwrap();
        assert_eq!(error.kind(), io::ErrorKind::InvalidInput);
        assert!(error.to_string().contains("needs Tor"));

        let dialer = Arc::new(Plain(Default::default()));
        set_route(Route::Socks(proxy(dialer.clone()).await));
        let mut routed = route_connect("127.0.0.1", target.port()).await.unwrap();
        routed.write_all(b"r").await.unwrap();
        routed.read_exact(&mut b).await.unwrap();
        assert_eq!(dialer.0.lock().unwrap().len(), 1);

        set_route(Route::Blocked("Tor is starting".into()));
        let error = route_connect("127.0.0.1", target.port()).await.err().unwrap();
        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(error.to_string().contains("Tor is starting"));
        // A route that was set before does not change an open connection.
        routed.write_all(b"r").await.unwrap();
        routed.read_exact(&mut b).await.unwrap();
        set_route(Route::Direct);
    }

    #[test]
    fn the_url_of_a_proxy_has_the_password_and_the_debug_text_has_not() {
        let proxy = Socks5 {
            addr: "127.0.0.1:9050".parse().unwrap(),
            auth: Some(("u".into(), "p4ss".into())),
        };
        assert_eq!(proxy.url(), "socks5h://u:p4ss@127.0.0.1:9050");
        assert!(!format!("{proxy:?}").contains("p4ss"));
        let open = Socks5 { addr: proxy.addr, auth: None };
        assert_eq!(open.url(), "socks5h://127.0.0.1:9050");
    }
}
