use std::io;
use std::net::{IpAddr, SocketAddr};
use std::sync::RwLock;

use tokio::io::{AsyncRead, AsyncWrite};
use tokio::net::TcpStream;

use crate::socks;

/// A SOCKS5 proxy.
#[derive(Clone, PartialEq, Eq)]
pub struct Socks5 {
    pub addr: SocketAddr,
    /// The user name and the password, if the proxy asks for them.
    pub auth: Option<(String, String)>,
}

impl std::fmt::Debug for Socks5 {
    /// The password is not in the text.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Socks5")
            .field("addr", &self.addr)
            .field("auth", &self.auth.as_ref().map(|(user, _)| user))
            .finish()
    }
}

impl Socks5 {
    /// The proxy as a URL for an HTTP client: `socks5h://user:password@host:port`. The
    /// `h` makes the proxy look up the names. The user name and the password must not
    /// have characters that a URL needs to escape; the ones that this crate makes are
    /// hexadecimal.
    pub fn url(&self) -> String {
        match &self.auth {
            Some((user, password)) => format!("socks5h://{user}:{password}@{}", self.addr),
            None => format!("socks5h://{}", self.addr),
        }
    }
}

/// How the app reaches a host.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Route {
    /// A TCP connection from the phone.
    Direct,
    /// Through a SOCKS5 proxy.
    Socks(Socks5),
    /// No connection. The text is the reason that the user sees.
    Blocked(String),
}

static ROUTE: RwLock<Route> = RwLock::new(Route::Direct);

/// The route now.
pub fn route() -> Route {
    ROUTE.read().unwrap_or_else(|e| e.into_inner()).clone()
}

/// Change the route. A connection that is open keeps the route that it had.
pub fn set_route(route: Route) {
    *ROUTE.write().unwrap_or_else(|e| e.into_inner()) = route;
}

/// A byte stream to a host, whatever the route.
pub trait AsyncStream: AsyncRead + AsyncWrite + Unpin + Send + std::fmt::Debug {}

impl<T: AsyncRead + AsyncWrite + Unpin + Send + std::fmt::Debug> AsyncStream for T {}

pub type BoxStream = Box<dyn AsyncStream>;

/// True for a `.onion` name, which only Tor can reach.
pub fn is_onion(host: &str) -> bool {
    host.trim_end_matches('.')
        .to_ascii_lowercase()
        .ends_with(".onion")
}

/// Open a TCP stream to `host:port` by the current [`route`]. `host` is a name or an IP
/// literal, with no brackets.
///
/// A direct route refuses an onion name before any lookup: the system resolver cannot
/// answer it, and the query would tell the DNS server which onion service the phone
/// wants.
pub async fn connect(host: &str, port: u16) -> io::Result<BoxStream> {
    match route() {
        Route::Direct if is_onion(host) => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "an onion address needs Tor: turn on Tor in the network settings",
        )),
        Route::Direct => {
            let tcp = match host.parse::<IpAddr>() {
                Ok(ip) => TcpStream::connect((ip, port)).await?,
                Err(_) => TcpStream::connect((host, port)).await?,
            };
            tcp.set_nodelay(true)?;
            Ok(Box::new(tcp))
        }
        Route::Socks(proxy) => {
            let stream = socks::connect(&proxy, host, port).await?;
            Ok(Box::new(stream))
        }
        Route::Blocked(reason) => Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!("the network route is blocked: {reason}"),
        )),
    }
}
