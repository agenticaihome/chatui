//! The embedded Arti client and its SOCKS5 proxy on the loopback.

use std::io;
use std::path::PathBuf;
use std::sync::Arc;

use arti_client::config::TorClientConfigBuilder;
use arti_client::{BootstrapBehavior, TorClient};
use celaut_net::socks::{listen_loopback, serve, Dialer};
use celaut_net::{BoxStream, Socks5};
use futures::StreamExt;
use ring::rand::{SecureRandom, SystemRandom};
use tokio::task::JoinHandle;

/// A SOCKS5 server that connects through Tor.
struct TorDialer(Arc<TorClient<tor_rtcompat::PreferredRuntime>>);

impl Dialer for TorDialer {
    async fn dial(&self, host: String, port: u16) -> io::Result<BoxStream> {
        let stream = self
            .0
            .connect((host.as_str(), port))
            .await
            .map_err(|e| io::Error::other(e.to_string()))?;
        Ok(Box::new(stream))
    }
}

/// A random string of hexadecimal characters.
fn random_hex(bytes: usize) -> Result<String, String> {
    let mut buffer = vec![0u8; bytes];
    SystemRandom::new()
        .fill(&mut buffer)
        .map_err(|_| "the system has no random numbers".to_string())?;
    Ok(hex::encode(buffer))
}

/// What a start gives: the proxy for the route. The tasks that keep it alive are in the
/// `tasks` that the caller passed.
pub(crate) struct Running {
    pub proxy: Socks5,
}

/// Start the client, its SOCKS5 port and the bootstrap. `progress` gets the percent of
/// the bootstrap. The result is a proxy that is ready, or the reason that it is not.
/// The tasks are in `tasks` also when the start fails, so the caller can stop them.
pub(crate) async fn start(
    state_dir: PathBuf,
    cache_dir: PathBuf,
    progress: impl Fn(u8) + Send + Sync + 'static,
    tasks: &mut Vec<JoinHandle<()>>,
) -> Result<Running, String> {
    let mut builder = TorClientConfigBuilder::from_directories(&state_dir, &cache_dir);
    // The directories are in the private storage of the app. On Android the checks of the
    // parent directories (owners and groups of /data) would refuse them.
    builder.storage().permissions().dangerously_trust_everyone();
    // Onion addresses of nodes. This is the default of Arti with `onion-service-client`;
    // it is written here so that a change of the default does not turn them off.
    builder.address_filter().allow_onion_addrs(true);
    let config = builder.build().map_err(|e| format!("the Tor settings: {e}"))?;
    let client = TorClient::builder()
        .config(config)
        .bootstrap_behavior(BootstrapBehavior::Manual)
        .create_unbootstrapped()
        .map_err(|e| format!("the Tor client: {e}"))?;

    let (listener, addr) = listen_loopback()
        .await
        .map_err(|e| format!("the SOCKS5 port: {e}"))?;
    let user = random_hex(16)?;
    let password = random_hex(16)?;
    tasks.push(tokio::spawn(serve(
        listener,
        (user.clone(), password.clone()),
        Arc::new(TorDialer(client.clone())),
    )));

    let mut events = client.bootstrap_events();
    tasks.push(tokio::spawn(async move {
        while let Some(status) = events.next().await {
            progress((status.as_frac().clamp(0.0, 1.0) * 100.0) as u8);
        }
    }));
    client
        .bootstrap()
        .await
        .map_err(|e| format!("Tor could not start: {e}"))?;
    Ok(Running {
        proxy: Socks5 {
            addr,
            auth: Some((user, password)),
        },
    })
}
