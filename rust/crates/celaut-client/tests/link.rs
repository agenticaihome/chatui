//! Import a service from a link (issue #135): a `.celaut.bee` file or a manifest of chunks,
//! checked while the bytes arrive, with retries, resume, cancel, a size limit and the check
//! of the free space (issue #151). The server is in memory ([`FakeSource`]), and so is the
//! free space ([`FreeSpace`]).

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use bee_rpc::buffer::buffer::Head;
use bee_rpc::buffer::Buffer;
use bee_rpc::hash::HashAlgorithm;
use bee_rpc::pointer::block_pointer;
use celaut_client::link::{
    can_resume, discard, download, downloads_dir, pending, FetchError, FreeSpace, LinkOptions,
    LinkProgress, Opened, Source,
};
use celaut_client::package::{library_path, Cancel, Check, Layout, PackageError};
use celaut_proto::celaut::metadata::hash_tag::Hash;
use celaut_proto::celaut::metadata::HashTag;
use celaut_proto::celaut::Metadata;
use celaut_wire::gateway::SHA3_256_TYPE;
use futures::future::BoxFuture;
use prost::Message;

fn dir() -> PathBuf {
    use std::sync::atomic::{AtomicU64, Ordering};
    static NEXT: AtomicU64 = AtomicU64::new(0);
    let d = std::env::temp_dir().join(format!(
        "celaut-link-{}-{}",
        std::process::id(),
        NEXT.fetch_add(1, Ordering::Relaxed)
    ));
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn record(buffer: &Buffer) -> Vec<u8> {
    let bytes = buffer.encode_to_vec();
    let mut out = (bytes.len() as u32).to_be_bytes().to_vec();
    out.extend(bytes);
    out
}

fn head(index: i32, chunk: &[u8], separator: bool) -> Buffer {
    Buffer {
        head: Some(Head {
            index,
            partitions: vec![],
        }),
        chunk: Some(chunk.to_vec()),
        separator: separator.then_some(true),
        ..Default::default()
    }
}

fn metadata(id: [u8; 32]) -> Vec<u8> {
    Metadata {
        hashtag: Some(HashTag {
            hash: vec![Hash {
                r#type: SHA3_256_TYPE.to_vec(),
                value: id.to_vec(),
            }],
            ..Default::default()
        }),
        ..Default::default()
    }
    .encode_to_vec()
}

/// A `nodo export` file: the Metadata (1) with `claimed` (or the true id), and the Service
/// (2): bytes, a block of `block` in records of 64 KiB, more bytes. Gives the file and the
/// true id of the service.
fn package(block: &[u8], claimed: Option<[u8; 32]>) -> (Vec<u8>, [u8; 32]) {
    let (before, after) = (b"service head".as_slice(), b"service tail".as_slice());
    let mut all = before.to_vec();
    all.extend_from_slice(block);
    all.extend_from_slice(after);
    let id: [u8; 32] = HashAlgorithm::Sha3_256.digest(&all).try_into().unwrap();
    let block_id = HashAlgorithm::Sha3_256.digest(block);
    let marker = || Buffer {
        block: Some(block_pointer(&block_id, HashAlgorithm::Sha3_256, false)),
        ..Default::default()
    };
    let mut out = record(&head(1, &metadata(claimed.unwrap_or(id)), true));
    out.extend(record(&head(2, before, false)));
    out.extend(record(&marker()));
    for piece in block.chunks(64 * 1024) {
        out.extend(record(&Buffer {
            chunk: Some(piece.to_vec()),
            ..Default::default()
        }));
    }
    out.extend(record(&marker()));
    out.extend(record(&Buffer {
        chunk: Some(after.to_vec()),
        separator: Some(true),
        ..Default::default()
    }));
    (out, id)
}

fn content(n: usize) -> Vec<u8> {
    (0..n).map(|i| (i * 31 % 251) as u8).collect()
}

/// What the fake server does for one request of a link.
#[derive(Clone, Debug)]
enum Plan {
    /// Answer well.
    Ok,
    /// Fail before the answer.
    Refuse,
    /// Give `n` bytes of the body, then fail.
    CutAfter(usize),
}

#[derive(Default)]
struct Server {
    files: HashMap<String, Vec<u8>>,
    /// The plan of the next requests of each link; `Ok` when empty.
    plans: HashMap<String, Vec<Plan>>,
    /// The links that do not take a `Range`.
    no_range: Vec<String>,
    /// Each request: the link and its `from`.
    log: Vec<(String, u64)>,
    /// The body bytes that the server gave.
    sent: u64,
    /// The links whose answers do not say their size (no `Content-Length`).
    no_total: Vec<String>,
}

#[derive(Clone, Default)]
struct FakeSource(Arc<Mutex<Server>>);

impl FakeSource {
    fn with(files: &[(&str, Vec<u8>)]) -> Self {
        let s = FakeSource::default();
        for (url, bytes) in files {
            s.0.lock().unwrap().files.insert(url.to_string(), bytes.clone());
        }
        s
    }
    fn plan(&self, url: &str, plans: &[Plan]) {
        self.0.lock().unwrap().plans.insert(url.into(), plans.to_vec());
    }
    fn no_range(&self, url: &str) {
        self.0.lock().unwrap().no_range.push(url.into());
    }
    fn no_total(&self, url: &str) {
        self.0.lock().unwrap().no_total.push(url.into());
    }
    fn log(&self) -> Vec<(String, u64)> {
        self.0.lock().unwrap().log.clone()
    }
    fn sent(&self) -> u64 {
        self.0.lock().unwrap().sent
    }
}

impl Source for FakeSource {
    fn open(&self, url: &str, from: u64) -> BoxFuture<'static, Result<Opened, FetchError>> {
        let server = self.0.clone();
        let url = url.split('#').next().unwrap().to_string();
        Box::pin(async move {
            let mut s = server.lock().unwrap();
            s.log.push((url.clone(), from));
            let plan = s
                .plans
                .get_mut(&url)
                .and_then(|p| (!p.is_empty()).then(|| p.remove(0)))
                .unwrap_or(Plan::Ok);
            let Some(file) = s.files.get(&url).cloned() else {
                return Err(FetchError::Fatal("HTTP 404".into()));
            };
            let start = if s.no_range.contains(&url) { 0 } else { from };
            let body: Vec<u8> = file[start as usize..].to_vec();
            let cut = match plan {
                Plan::Ok => None,
                Plan::Refuse => return Err(FetchError::Retry("connection refused".into())),
                Plan::CutAfter(n) => Some(n.min(body.len())),
            };
            let given = cut.unwrap_or(body.len());
            s.sent += given as u64;
            let mut items: Vec<Result<Vec<u8>, FetchError>> =
                body[..given].chunks(7000).map(|c| Ok(c.to_vec())).collect();
            if cut.is_some() {
                items.push(Err(FetchError::Retry("connection reset".into())));
            }
            let total = (!s.no_total.contains(&url)).then_some(file.len() as u64);
            Ok(Opened {
                start,
                total,
                body: Box::pin(futures::stream::iter(items)),
            })
        })
    }
}

fn options() -> LinkOptions {
    LinkOptions {
        backoff: Duration::from_millis(1),
        idle: Duration::from_secs(5),
        // The free space of the machine of the test is not checked, except in the tests of
        // the free space.
        free_space: FreeSpace(Arc::new(|_| None)),
        ..LinkOptions::default()
    }
}

fn no_downloads_left(d: &Path) {
    let left: Vec<_> = std::fs::read_dir(downloads_dir(d))
        .map(|r| r.flatten().map(|e| e.path()).collect())
        .unwrap_or_default();
    assert!(left.is_empty(), "{left:?}");
}

#[tokio::test]
async fn a_single_file_is_downloaded_checked_and_loaded() {
    let (file, id) = package(&content(300_000), None);
    let url = "https://h/echo.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    let d = dir();
    let cancel = Cancel::new();
    let progress = LinkProgress::new();
    let got = download(&source, url, &d, &options(), &cancel, &progress).await.unwrap();
    assert_eq!(got.service_id, id);
    assert_eq!(got.layout, Layout::NodoExport);
    assert_eq!((got.bytes, got.chunks, got.resumed), (file.len() as u64, 0, false));
    assert_eq!(got.path, library_path(&d, &id));
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
    assert_eq!(cancel.bytes(), file.len() as u64);
    assert_eq!(progress.total(), Some(file.len() as u64));
    assert_eq!(progress.chunk(), (0, 0));
    assert_eq!(source.log(), vec![(url.to_string(), 0)]);
    no_downloads_left(&d);
}

#[tokio::test]
async fn a_download_can_be_kept_without_the_content_of_its_blocks() {
    use celaut_client::package::Storage;
    let (file, id) = package(&content(300_000), None);
    let url = "https://h/echo.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    let d = dir();
    let options = LinkOptions {
        storage: Storage::WithoutFilesystem,
        ..options()
    };
    let got = download(&source, url, &d, &options, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap();
    assert_eq!(got.service_id, id);
    assert!(!got.filesystem_kept);
    // The whole file was downloaded and checked; the library keeps the small part.
    let stored = std::fs::metadata(&got.path).unwrap().len();
    assert_eq!(got.bytes, stored);
    assert!(stored < 1_000, "{stored} bytes of {}", file.len());
    no_downloads_left(&d);
}

#[tokio::test]
async fn a_manifest_gives_the_chunks_in_order() {
    let (file, id) = package(&content(500_000), None);
    let parts: Vec<Vec<u8>> = file.chunks(120_000).map(<[u8]>::to_vec).collect();
    let mut files: Vec<(String, Vec<u8>)> = parts
        .iter()
        .enumerate()
        .map(|(i, p)| (format!("https://cdn/part{i}"), p.clone()))
        .collect();
    let manifest: String = files.iter().map(|(u, _)| format!("{u}\r\n")).collect();
    files.push(("https://h/echo.celaut.bee.txt".into(), manifest.into_bytes()));
    let refs: Vec<(&str, Vec<u8>)> = files.iter().map(|(u, b)| (u.as_str(), b.clone())).collect();
    let source = FakeSource::with(&refs);
    let d = dir();
    let progress = LinkProgress::new();
    let got = download(&source, "https://h/echo.celaut.bee.txt", &d, &options(), &Cancel::new(), &progress)
        .await
        .unwrap();
    assert_eq!(got.service_id, id);
    assert_eq!(got.chunks, parts.len() as u32);
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
    assert_eq!(progress.chunk(), (parts.len() as u32, parts.len() as u32));
    // The size of the whole file is not known from a chunk.
    assert_eq!(progress.total(), None);
    let asked: Vec<String> = source.log().into_iter().map(|(u, _)| u).collect();
    assert_eq!(asked[0], "https://h/echo.celaut.bee.txt");
    assert_eq!(asked[1..], files[..parts.len()].iter().map(|(u, _)| u.clone()).collect::<Vec<_>>());
    no_downloads_left(&d);
}

#[tokio::test]
async fn a_failed_chunk_is_tried_again_from_where_it_stopped() {
    let (file, id) = package(&content(400_000), None);
    let (a, b) = file.split_at(200_000);
    let source = FakeSource::with(&[
        ("https://h/m", b"https://c/a\nhttps://c/b\n".to_vec()),
        ("https://c/a", a.to_vec()),
        ("https://c/b", b.to_vec()),
    ]);
    source.plan("https://c/b", &[Plan::Refuse, Plan::CutAfter(50_000), Plan::CutAfter(10)]);
    let d = dir();
    let progress = LinkProgress::new();
    let got = download(&source, "https://h/m", &d, &options(), &Cancel::new(), &progress).await.unwrap();
    assert_eq!(got.service_id, id);
    assert_eq!(progress.retries(), 3);
    // The chunk a is asked for once; b again from the bytes that it gave.
    assert_eq!(
        source.log(),
        vec![
            ("https://h/m".to_string(), 0),
            ("https://c/a".to_string(), 0),
            ("https://c/b".to_string(), 0),
            ("https://c/b".to_string(), 0),
            ("https://c/b".to_string(), 50_000),
            ("https://c/b".to_string(), 50_010),
        ]
    );
    // No byte came twice.
    assert_eq!(source.sent(), file.len() as u64 + 24);
}

#[tokio::test]
async fn a_server_with_no_range_gives_the_chunk_again_from_its_start() {
    let (file, id) = package(&content(300_000), None);
    let (a, b) = file.split_at(100_000);
    let source = FakeSource::with(&[
        ("https://h/m", b"https://c/a\nhttps://c/b\n".to_vec()),
        ("https://c/a", a.to_vec()),
        ("https://c/b", b.to_vec()),
    ]);
    source.no_range("https://c/b");
    source.plan("https://c/b", &[Plan::CutAfter(70_000)]);
    let d = dir();
    let got = download(&source, "https://h/m", &d, &options(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap();
    assert_eq!(got.service_id, id);
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
}

#[tokio::test]
async fn a_download_that_stops_goes_on_from_the_disk() {
    let (file, id) = package(&content(600_000), None);
    let parts: Vec<Vec<u8>> = file.chunks(150_000).map(<[u8]>::to_vec).collect();
    let urls: Vec<String> = (0..parts.len()).map(|i| format!("https://c/{i}")).collect();
    let mut files: Vec<(&str, Vec<u8>)> =
        urls.iter().zip(&parts).map(|(u, p)| (u.as_str(), p.clone())).collect();
    let manifest = urls.join("\n");
    files.push(("https://h/m", manifest.into_bytes()));
    let source = FakeSource::with(&files);
    // The third chunk fails at each try: the download stops after its tries.
    let fails = vec![Plan::CutAfter(1000); 5];
    source.plan(&urls[2], &fails);
    let d = dir();
    let opts = options();
    let err = download(&source, "https://h/m", &d, &opts, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(can_resume(&err), "{err}");
    let left = pending(&d).unwrap();
    assert_eq!(left.url, "https://h/m");
    assert_eq!(left.bytes, 2 * 150_000 + 5 * 1000);
    assert!(!library_path(&d, &id).exists());

    // Later: the same link goes on. Chunks 0 and 1 are not asked again, and the chunk 2
    // goes on from its byte 5000.
    let before = source.log().len();
    let progress = LinkProgress::new();
    let got = download(&source, "https://h/m", &d, &opts, &Cancel::new(), &progress).await.unwrap();
    assert!(got.resumed);
    assert_eq!(got.service_id, id);
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
    let again: Vec<(String, u64)> = source.log()[before..].to_vec();
    assert_eq!(again[0], (urls[2].clone(), 5000));
    assert!(again.iter().all(|(u, _)| *u != urls[0] && *u != urls[1] && u != "https://h/m"));
    assert!(pending(&d).is_none());
}

#[tokio::test]
async fn a_single_file_goes_on_with_a_range() {
    let (file, id) = package(&content(300_000), None);
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    source.plan(url, &vec![Plan::CutAfter(40_000); 5]);
    let d = dir();
    let err = download(&source, url, &d, &options(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(can_resume(&err));
    assert_eq!(pending(&d).unwrap().bytes, 200_000);
    let got = download(&source, url, &d, &options(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap();
    assert_eq!(got.service_id, id);
    assert_eq!(source.log().last().unwrap(), &(url.to_string(), 200_000));
}

#[tokio::test]
async fn a_download_of_another_link_deletes_the_one_that_stopped() {
    let (file, _) = package(&content(100_000), None);
    let source = FakeSource::with(&[("https://h/a", file.clone()), ("https://h/b", file)]);
    source.plan("https://h/a", &vec![Plan::CutAfter(1000); 5]);
    source.plan("https://h/b", &vec![Plan::CutAfter(1000); 5]);
    let d = dir();
    let opts = options();
    assert!(download(&source, "https://h/a", &d, &opts, &Cancel::new(), &LinkProgress::new()).await.is_err());
    assert_eq!(pending(&d).unwrap().url, "https://h/a");
    assert!(download(&source, "https://h/b", &d, &opts, &Cancel::new(), &LinkProgress::new()).await.is_err());
    assert_eq!(pending(&d).unwrap().url, "https://h/b");
    assert_eq!(std::fs::read_dir(downloads_dir(&d)).unwrap().count(), 1);
    discard(&d).unwrap();
    assert!(pending(&d).is_none());
}

#[tokio::test]
async fn a_cancel_deletes_the_files() {
    let (file, _) = package(&content(200_000), None);
    let url = "https://h/x";
    let source = FakeSource::with(&[(url, file)]);
    // Every try fails, and the waits are long: the cancel comes during a wait.
    source.plan(url, &vec![Plan::CutAfter(30_000); 5]);
    let d = dir();
    let cancel = Cancel::new();
    let opts = LinkOptions {
        backoff: Duration::from_secs(30),
        ..options()
    };
    let stop = cancel.clone();
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_millis(300)).await;
        stop.cancel();
    });
    let err = download(&source, url, &d, &opts, &cancel, &LinkProgress::new()).await.unwrap_err();
    assert!(matches!(err, PackageError::Cancelled), "{err}");
    assert!(pending(&d).is_none());
    no_downloads_left(&d);
}

#[tokio::test]
async fn a_file_larger_than_the_limit_stops_and_is_deleted() {
    let (file, _) = package(&content(300_000), None);
    let source = FakeSource::with(&[
        ("https://h/x", file.clone()),
        ("https://h/m", b"https://c/a\nhttps://c/b".to_vec()),
        ("https://c/a", file[..200_000].to_vec()),
        ("https://c/b", file[200_000..].to_vec()),
    ]);
    let d = dir();
    let opts = LinkOptions {
        max_bytes: 250_000,
        ..options()
    };
    // The size that the server says is enough to stop a single file at once.
    let err = download(&source, "https://h/x", &d, &opts, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(matches!(err, PackageError::TooLarge(250_000)), "{err}");
    // A manifest stops when its chunks pass the limit.
    let err = download(&source, "https://h/m", &d, &opts, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(matches!(err, PackageError::TooLarge(_)), "{err}");
    no_downloads_left(&d);
}

#[tokio::test]
async fn a_file_that_fails_the_check_is_deleted() {
    let d = dir();
    // The Metadata names another service than the one that the Service hashes to.
    let (lie, true_id) = package(&content(100_000), Some([9u8; 32]));
    // A byte of the block changed: the block does not hold what its id names.
    let (mut changed, _) = package(&content(100_000), None);
    let at = changed.len() - 60_000;
    changed[at] ^= 1;
    // Cut in the middle.
    let (whole, _) = package(&content(100_000), None);
    let cut = whole[..whole.len() / 2].to_vec();
    let source = FakeSource::with(&[
        ("https://h/lie", lie),
        ("https://h/changed", changed),
        ("https://h/cut", cut),
        ("https://h/text", b"hello\n".to_vec()),
        ("https://h/empty", Vec::new()),
        ("https://h/garbage", vec![0, 0, 0, 3, 0xff, 0xff, 0xff]),
    ]);
    for (url, want) in [
        ("https://h/lie", hex::encode(true_id)),
        ("https://h/changed", "holds other bytes".to_string()),
        ("https://h/cut", "cut".to_string()),
        ("https://h/text", "neither a service file nor a list of links".to_string()),
        ("https://h/empty", "empty".to_string()),
        ("https://h/garbage", "not a Buffer".to_string()),
    ] {
        let err = download(&source, url, &d, &options(), &Cancel::new(), &LinkProgress::new())
            .await
            .unwrap_err();
        assert!(matches!(err, PackageError::Invalid(_)), "{url}: {err}");
        assert!(err.to_string().contains(&want), "{url}: {err}");
        no_downloads_left(&d);
    }
    assert!(!library_path(&d, &true_id).exists());
}

#[tokio::test]
async fn the_link_can_name_the_service() {
    let (file, id) = package(&content(50_000), None);
    let source = FakeSource::with(&[("https://h/x", file)]);
    let d = dir();
    let good = format!("https://h/x#{}", hex::encode(id));
    assert!(download(&source, &good, &d, &options(), &Cancel::new(), &LinkProgress::new()).await.is_ok());
    let other = format!("https://h/x#{}", "11".repeat(32));
    let err = download(&source, &other, &d, &options(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(err.to_string().contains("asks for the service"), "{err}");
}

#[tokio::test]
async fn http_needs_the_consent_of_the_user_and_404_does_not_retry() {
    let (file, _) = package(&content(10_000), None);
    let source = FakeSource::with(&[("http://h/x", file)]);
    let d = dir();
    let err = download(&source, "http://h/x", &d, &options(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(err.to_string().contains("not encrypted"), "{err}");
    assert!(source.log().is_empty());
    let opts = LinkOptions {
        allow_http: true,
        ..options()
    };
    assert!(download(&source, "http://h/x", &d, &opts, &Cancel::new(), &LinkProgress::new()).await.is_ok());
    // A link that is not there: one request, no retry.
    let err = download(&source, "https://h/none", &d, &options(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(err.to_string().contains("404"), "{err}");
    assert_eq!(source.log().iter().filter(|(u, _)| u == "https://h/none").count(), 1);
    // Nothing came: nothing is kept to go on with.
    assert!(pending(&d).is_none());
}

#[test]
fn the_check_takes_the_bytes_in_any_pieces() {
    let (file, id) = package(&content(200_000), None);
    for size in [1, 3, 4, 5, 4096, 70_000, file.len()] {
        let mut check = Check::new();
        for piece in file.chunks(size) {
            check.feed(piece).unwrap();
        }
        let checked = check.finish().unwrap();
        assert_eq!((checked.service_id, checked.bytes), (id, file.len() as u64), "{size}");
    }
}

#[test]
fn the_check_of_a_real_export() {
    // `CELAUT_BEE=<file of nodo export>`: the id of the service is the hash of its Service.
    let Ok(path) = std::env::var("CELAUT_BEE") else {
        return;
    };
    let file = std::fs::read(path).unwrap();
    let mut check = Check::new();
    for piece in file.chunks(1 << 20) {
        check.feed(piece).unwrap();
    }
    println!("{}", hex::encode(check.finish().unwrap().service_id));
}

fn stripped() -> LinkOptions {
    LinkOptions {
        storage: celaut_client::package::Storage::WithoutFilesystem,
        ..options()
    }
}

/// The size of the file that a download keeps on disk while it runs.
fn partial_len(d: &Path) -> u64 {
    std::fs::read_dir(downloads_dir(d))
        .unwrap()
        .flatten()
        .find_map(|e| std::fs::metadata(e.path().join("service.bee.partial")).ok())
        .map_or(0, |m| m.len())
}

#[tokio::test]
async fn a_download_without_the_filesystem_never_has_the_content_of_the_blocks_on_disk_and_goes_on() {
    let (file, id) = package(&content(600_000), None);
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    // What a whole download of the same file keeps, for the comparison.
    let whole_dir = dir();
    let reference = download(&source, url, &whole_dir, &stripped(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap();
    let want = std::fs::read(&reference.path).unwrap();

    source.plan(url, &vec![Plan::CutAfter(40_000); 5]);
    let d = dir();
    let err = download(&source, url, &d, &stripped(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(can_resume(&err), "{err}");
    // 200 000 bytes arrived, and the disk has only what is outside the blocks.
    let left = pending(&d).unwrap();
    assert_eq!(left.bytes, 200_000);
    assert!(partial_len(&d) < 1_000, "{} bytes", partial_len(&d));

    let before = source.log().len();
    let cancel = Cancel::new();
    let got = download(&source, url, &d, &stripped(), &cancel, &LinkProgress::new()).await.unwrap();
    assert!(got.resumed);
    assert!(!got.filesystem_kept);
    assert_eq!(got.service_id, id);
    // It went on with a Range from the byte that the check had read, not from the start.
    assert_eq!(source.log()[before], (url.to_string(), 200_000));
    assert_eq!(cancel.bytes(), file.len() as u64);
    // The same file as a download with no stop.
    assert_eq!(std::fs::read(&got.path).unwrap(), want);
    assert_eq!(got.bytes, want.len() as u64);
    assert!(want.len() < 1_000);
    no_downloads_left(&d);
}

#[tokio::test]
async fn a_download_without_the_filesystem_goes_on_by_chunks_and_without_a_range() {
    let (file, id) = package(&content(600_000), None);
    let parts: Vec<Vec<u8>> = file.chunks(150_000).map(<[u8]>::to_vec).collect();
    let urls: Vec<String> = (0..parts.len()).map(|i| format!("https://c/{i}")).collect();
    let mut files: Vec<(&str, Vec<u8>)> =
        urls.iter().zip(&parts).map(|(u, p)| (u.as_str(), p.clone())).collect();
    files.push(("https://h/m", urls.join("\n").into_bytes()));
    let source = FakeSource::with(&files);
    // The chunk 1 does not take a Range and the chunk 2 fails at each try.
    source.no_range(&urls[1]);
    source.plan(&urls[1], &[Plan::CutAfter(70_000)]);
    source.plan(&urls[2], &vec![Plan::CutAfter(1000); 5]);
    let d = dir();
    let err = download(&source, "https://h/m", &d, &stripped(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(can_resume(&err), "{err}");
    assert_eq!(pending(&d).unwrap().bytes, 2 * 150_000 + 5 * 1000);
    assert!(partial_len(&d) < 1_000);

    let before = source.log().len();
    let got = download(&source, "https://h/m", &d, &stripped(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap();
    assert!(got.resumed);
    assert_eq!(got.service_id, id);
    assert_eq!(got.chunks as usize, urls.len());
    assert_eq!(source.log()[before], (urls[2].clone(), 5000));
    assert!(got.bytes < 1_000);
}

#[tokio::test]
async fn a_download_that_stopped_does_not_go_on_with_the_other_storage() {
    let (file, id) = package(&content(300_000), None);
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    source.plan(url, &vec![Plan::CutAfter(40_000); 5]);
    let d = dir();
    download(&source, url, &d, &stripped(), &Cancel::new(), &LinkProgress::new()).await.unwrap_err();
    let before = source.log().len();
    let got = download(&source, url, &d, &options(), &Cancel::new(), &LinkProgress::new()).await.unwrap();
    // The whole file was asked for from its start: the first bytes are not on disk.
    assert!(!got.resumed);
    assert_eq!(source.log()[before], (url.to_string(), 0));
    assert!(got.filesystem_kept);
    assert_eq!(std::fs::read(library_path(&d, &id)).unwrap(), file);
}

#[tokio::test]
async fn a_download_without_the_filesystem_checks_the_blocks_as_it_reads_them() {
    let d = dir();
    let (mut changed, id) = package(&content(100_000), None);
    let at = changed.len() - 60_000;
    changed[at] ^= 1;
    let (lie, lie_id) = package(&content(100_000), Some([9u8; 32]));
    let source = FakeSource::with(&[("https://h/changed", changed), ("https://h/lie", lie)]);
    let err = download(&source, "https://h/changed", &d, &stripped(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(matches!(&err, PackageError::Invalid(t) if t.contains("holds other bytes")), "{err}");
    no_downloads_left(&d);
    let err = download(&source, "https://h/lie", &d, &stripped(), &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(err.to_string().contains(&hex::encode(lie_id)), "{err}");
    no_downloads_left(&d);
    assert!(!library_path(&d, &id).exists() && !library_path(&d, &lie_id).exists());
}

#[tokio::test]
async fn the_limit_of_a_download_without_the_filesystem_counts_the_bytes_that_are_kept() {
    // The limit is smaller than the service, and the download is still good: the content of
    // the blocks is not kept.
    let (file, id) = package(&content(300_000), None);
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    let small = LinkOptions {
        max_bytes: 50_000,
        ..stripped()
    };
    let d = dir();
    let got = download(&source, url, &d, &small, &Cancel::new(), &LinkProgress::new()).await.unwrap();
    assert_eq!(got.service_id, id);
    // The whole download with the same limit is refused.
    let whole = LinkOptions { max_bytes: 50_000, ..options() };
    let err = download(&source, url, &dir(), &whole, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(matches!(err, PackageError::TooLarge(50_000)), "{err}");
}

// ─── Free space (issue #151) ─────────────────────────────────────────────────────────

/// The space that must stay free in these tests.
const MARGIN: u64 = 1000;

/// A phone with `free` bytes free, which the test can change.
fn free_of(free: &Arc<AtomicU64>) -> FreeSpace {
    let free = free.clone();
    FreeSpace(Arc::new(move |_| Some(free.load(Ordering::Acquire))))
}

/// A phone with a disk of `cap` bytes for the download: the bytes of the download on disk
/// take from it.
fn disk_of(cap: &Arc<AtomicU64>) -> FreeSpace {
    let cap = cap.clone();
    FreeSpace(Arc::new(move |folder: &Path| {
        let used = std::fs::metadata(folder.join("service.bee.partial")).map_or(0, |m| m.len());
        Some(cap.load(Ordering::Acquire).saturating_sub(used))
    }))
}

fn with_free(space: FreeSpace, base: LinkOptions) -> LinkOptions {
    LinkOptions {
        min_free: MARGIN,
        free_space: space,
        ..base
    }
}

fn no_space(err: &PackageError) -> (u64, u64) {
    match err {
        PackageError::NoSpace { needed, available } => (*needed, *available),
        e => panic!("not NoSpace: {e}"),
    }
}

#[tokio::test]
async fn a_file_that_does_not_fit_is_refused_before_its_first_byte() {
    let (file, id) = package(&content(300_000), None);
    let len = file.len() as u64;
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    let free = Arc::new(AtomicU64::new(len + MARGIN - 1));
    let opts = with_free(free_of(&free), options());
    let d = dir();
    let cancel = Cancel::new();
    let err = download(&source, url, &d, &opts, &cancel, &LinkProgress::new()).await.unwrap_err();
    // The size of the file and the margin.
    assert_eq!(no_space(&err), (len + MARGIN, len + MARGIN - 1));
    // Nothing was written, and nothing is kept: there is nothing to go on from.
    assert_eq!(cancel.bytes(), 0);
    assert!(pending(&d).is_none());
    no_downloads_left(&d);
    assert_eq!(source.log().len(), 1);

    // With the space, the same link downloads.
    free.store(len + MARGIN, Ordering::Release);
    let got = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap();
    assert_eq!(got.service_id, id);
    assert!(!got.resumed);
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
}

#[tokio::test]
async fn the_limit_of_4_gib_is_checked_before_the_free_space() {
    let (file, _) = package(&content(300_000), None);
    let source = FakeSource::with(&[("https://h/x", file)]);
    let opts = LinkOptions {
        max_bytes: 250_000,
        ..with_free(FreeSpace(Arc::new(|_| Some(0))), options())
    };
    let d = dir();
    let err = download(&source, "https://h/x", &d, &opts, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert!(matches!(err, PackageError::TooLarge(250_000)), "{err}");
    assert_eq!(LinkOptions::default().max_bytes, 4 * 1024 * 1024 * 1024);
    assert_eq!(LinkOptions::default().min_free, 256 * 1024 * 1024);
}

#[tokio::test]
async fn a_download_that_goes_on_needs_only_the_space_of_the_rest() {
    let (file, id) = package(&content(300_000), None);
    let len = file.len() as u64;
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    source.plan(url, &vec![Plan::CutAfter(40_000); 5]);
    let d = dir();
    let free = Arc::new(AtomicU64::new(u64::MAX));
    let opts = with_free(free_of(&free), options());
    download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap_err();
    assert_eq!(pending(&d).unwrap().bytes, 200_000);

    // Less than the rest: refused, and the 200 000 bytes stay.
    let rest = len - 200_000;
    free.store(rest + MARGIN - 1, Ordering::Release);
    let err = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap_err();
    assert_eq!(no_space(&err), (rest + MARGIN, rest + MARGIN - 1));
    assert!(can_resume(&err));
    assert_eq!(pending(&d).unwrap().bytes, 200_000);

    // The rest fits, not the whole file: it goes on.
    free.store(rest + MARGIN, Ordering::Release);
    let got = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap();
    assert!(got.resumed);
    assert_eq!(got.service_id, id);
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
    assert_eq!(source.log().last().unwrap(), &(url.to_string(), 200_000));
}

#[tokio::test]
async fn a_manifest_stops_at_the_chunk_that_does_not_fit_and_keeps_the_ones_before() {
    let (file, id) = package(&content(400_000), None);
    let (a, b) = file.split_at(200_000);
    let source = FakeSource::with(&[
        ("https://h/m", b"https://c/a\nhttps://c/b\n".to_vec()),
        ("https://c/a", a.to_vec()),
        ("https://c/b", b.to_vec()),
    ]);
    // Room for the chunk a and 50 bytes more.
    let cap = Arc::new(AtomicU64::new(200_000 + MARGIN + 50));
    let opts = with_free(disk_of(&cap), options());
    let d = dir();
    let progress = LinkProgress::new();
    let err = download(&source, "https://h/m", &d, &opts, &Cancel::new(), &progress).await.unwrap_err();
    // The chunk b is checked with its own size when it starts.
    assert_eq!(no_space(&err), (b.len() as u64 + MARGIN, MARGIN + 50));
    assert_eq!(progress.chunk(), (2, 2));
    assert!(can_resume(&err));
    assert_eq!(pending(&d).unwrap().bytes, 200_000);
    assert_eq!(
        source.log(),
        vec![
            ("https://h/m".to_string(), 0),
            ("https://c/a".to_string(), 0),
            ("https://c/b".to_string(), 0),
        ]
    );

    // The user frees space and taps Continue: the chunk a is not asked again.
    cap.store(u64::MAX, Ordering::Release);
    let got = download(&source, "https://h/m", &d, &opts, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap();
    assert!(got.resumed);
    assert_eq!(got.service_id, id);
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
    assert_eq!(source.log()[3..], [("https://c/b".to_string(), 0)]);
}

#[tokio::test]
async fn a_manifest_refused_at_its_first_chunk_keeps_nothing() {
    let (file, _) = package(&content(300_000), None);
    let (a, b) = file.split_at(200_000);
    let source = FakeSource::with(&[
        ("https://h/m", b"https://c/a\nhttps://c/b\n".to_vec()),
        ("https://c/a", a.to_vec()),
        ("https://c/b", b.to_vec()),
    ]);
    let opts = with_free(FreeSpace(Arc::new(|_| Some(10_000))), options());
    let d = dir();
    let err = download(&source, "https://h/m", &d, &opts, &Cancel::new(), &LinkProgress::new())
        .await
        .unwrap_err();
    assert_eq!(no_space(&err), (200_000 + MARGIN, 10_000));
    assert!(pending(&d).is_none());
    no_downloads_left(&d);
}

#[tokio::test]
async fn without_the_filesystem_only_the_margin_counts() {
    let (file, id) = package(&content(600_000), None);
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file)]);
    let free = Arc::new(AtomicU64::new(MARGIN - 1));
    let opts = with_free(free_of(&free), stripped());
    let d = dir();
    // The size of what is written is not known: the margin is checked at the start.
    let err = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap_err();
    assert_eq!(no_space(&err), (MARGIN, MARGIN - 1));
    no_downloads_left(&d);
    // The service is 600 000 bytes, and the margin is enough: its blocks are not written.
    free.store(MARGIN, Ordering::Release);
    let got = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap();
    assert_eq!(got.service_id, id);
}

/// A phone whose free space falls to `after` once the download asked for it `calls` times.
fn falls(calls: u32, before: u64, after: u64) -> (FreeSpace, Arc<AtomicU64>) {
    let asked = Arc::new(AtomicU64::new(0));
    let count = asked.clone();
    let space = FreeSpace(Arc::new(move |_| {
        let n = count.fetch_add(1, Ordering::AcqRel);
        Some(if n < calls as u64 { before } else { after })
    }));
    (space, asked)
}

#[tokio::test]
async fn without_the_filesystem_the_margin_is_checked_again_and_the_download_goes_on() {
    let (file, id) = package(&content(600_000), None);
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    // The phone fills (another app) after the check at the start.
    let (space, asked) = falls(1, 1_000_000, 10);
    let opts = LinkOptions {
        room_every: 100_000,
        ..with_free(space, stripped())
    };
    let d = dir();
    let err = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap_err();
    assert_eq!(no_space(&err), (MARGIN, 10));
    assert_eq!(asked.load(Ordering::Acquire), 2);
    // It stopped after 100 000 bytes (in pieces of 7000), and keeps its checkpoint.
    let kept = pending(&d).unwrap().bytes;
    assert_eq!(kept, 105_000);
    assert!(partial_len(&d) < 1_000);

    let opts = LinkOptions {
        room_every: 100_000,
        ..with_free(FreeSpace(Arc::new(|_| Some(u64::MAX))), stripped())
    };
    let got = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap();
    assert!(got.resumed);
    assert_eq!(got.service_id, id);
    assert_eq!(source.log().last().unwrap(), &(url.to_string(), kept));
}

#[tokio::test]
async fn an_answer_with_no_size_checks_the_margin_at_the_start_and_as_it_writes() {
    let (file, id) = package(&content(300_000), None);
    let url = "https://h/x.celaut.bee";
    let source = FakeSource::with(&[(url, file.clone())]);
    source.no_total(url);
    let d = dir();
    // An unknown size alone is not refused.
    let opts = with_free(FreeSpace(Arc::new(|_| Some(MARGIN))), options());
    let got = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap();
    assert_eq!(got.service_id, id);

    let d = dir();
    let opts = with_free(FreeSpace(Arc::new(|_| Some(MARGIN - 1))), options());
    let err = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap_err();
    assert_eq!(no_space(&err), (MARGIN, MARGIN - 1));
    no_downloads_left(&d);

    // The disk fills during the download: it stops, keeps its bytes, and goes on.
    let (space, _) = falls(1, u64::MAX, 0);
    let opts = LinkOptions {
        room_every: 100_000,
        ..with_free(space, options())
    };
    let err = download(&source, url, &d, &opts, &Cancel::new(), &LinkProgress::new()).await.unwrap_err();
    assert_eq!(no_space(&err), (MARGIN, 0));
    assert_eq!(pending(&d).unwrap().bytes, 105_000);
    let got = download(&source, url, &d, &options(), &Cancel::new(), &LinkProgress::new()).await.unwrap();
    assert!(got.resumed);
    assert_eq!(std::fs::read(&got.path).unwrap(), file);
    assert_eq!(source.log().last().unwrap(), &(url.to_string(), 105_000));
}
