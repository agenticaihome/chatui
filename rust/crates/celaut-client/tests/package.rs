//! A service as a package: save the Buffers of `GetService`, inspect a `.bee` file, and
//! read it for a node with the indices of `StartService`.

use std::path::PathBuf;

use bee_rpc::buffer::buffer::Head;
use bee_rpc::buffer::Buffer;
use bee_rpc::frame::{serialize_part, ParseOptions, Parser, Part};
use bee_rpc::hash::HashAlgorithm;
use bee_rpc::pointer::block_pointer;
use celaut_client::package::{inspect, read, save, Cancel, Layout, PackageError};
use celaut_proto::celaut::metadata::hash_tag::Hash;
use celaut_proto::celaut::metadata::HashTag;
use celaut_proto::celaut::Metadata;
use celaut_wire::gateway::SHA3_256_TYPE;
use celaut_wire::{Buffers, WireError};
use prost::Message;
use tokio_stream::StreamExt;

fn dir() -> PathBuf {
    let d = std::env::temp_dir().join(format!(
        "celaut-package-{}-{}",
        std::process::id(),
        rand_suffix()
    ));
    std::fs::create_dir_all(&d).unwrap();
    d
}

/// A number that no other test of this process has. The clock was not enough: two tests that
/// start together can read the same nanosecond, share a directory, and remove each other's
/// files.
fn rand_suffix() -> u64 {
    use std::sync::atomic::{AtomicU64, Ordering};
    static NEXT: AtomicU64 = AtomicU64::new(0);
    NEXT.fetch_add(1, Ordering::Relaxed)
}

const SERVICE_ID: [u8; 32] = [7u8; 32];

fn metadata() -> Vec<u8> {
    metadata_of(SERVICE_ID)
}

/// A Metadata that names the service `id`.
fn metadata_of(id: [u8; 32]) -> Vec<u8> {
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

/// The Buffers of a service part with one block, as a node sends a Service: a head,
/// some bytes, a block with its content, more bytes, a separator.
fn service_buffers(index: i32, content: &[u8]) -> Vec<Buffer> {
    let id = HashAlgorithm::Sha3_256.digest(content);
    let marker = || Buffer {
        block: Some(block_pointer(&id, HashAlgorithm::Sha3_256, false)),
        ..Default::default()
    };
    vec![
        Buffer {
            head: Some(Head {
                index,
                partitions: vec![],
            }),
            chunk: Some(b"before".to_vec()),
            ..Default::default()
        },
        marker(),
        Buffer {
            chunk: Some(content.to_vec()),
            ..Default::default()
        },
        marker(),
        Buffer {
            chunk: Some(b"after".to_vec()),
            separator: Some(true),
            ..Default::default()
        },
    ]
}

/// The id of the service whose Service part is `service`: the SHA3-256 of its chunks in
/// order (`docs/celaut/package.md`).
fn id_of(service: &[Buffer]) -> [u8; 32] {
    let mut hasher = HashAlgorithm::Sha3_256.hasher();
    for b in service {
        if let Some(c) = &b.chunk {
            hasher.update(c);
        }
    }
    hasher.finalize().as_slice().try_into().unwrap()
}

/// What `GetService` answers: the hash (4), the Metadata (5), the Service (6), and a
/// flow control signal at the end.
fn get_service_answer(content: &[u8]) -> Vec<Buffer> {
    answer_for(content, SERVICE_ID)
}

/// [`get_service_answer`] for the service `id`.
fn answer_for(content: &[u8], id: [u8; 32]) -> Vec<Buffer> {
    let hash = Hash {
        r#type: SHA3_256_TYPE.to_vec(),
        value: id.to_vec(),
    };
    let mut out: Vec<Buffer> = serialize_part(&Part::new(4, hash.encode_to_vec())).collect();
    out.extend(serialize_part(&Part::new(5, metadata_of(id))));
    out.extend(service_buffers(6, content));
    out.push(Buffer {
        signal: Some(true),
        ..Default::default()
    });
    out
}

fn stream(buffers: Vec<Buffer>) -> Buffers {
    Box::pin(tokio_stream::iter(buffers.into_iter().map(Ok)))
}

async fn collect(mut s: Buffers) -> Result<Vec<Buffer>, WireError> {
    let mut out = Vec::new();
    while let Some(item) = s.next().await {
        out.push(item?);
    }
    Ok(out)
}

/// The parts that a node parses from `buffers`, with the indices of StartService.
fn parse(buffers: Vec<Buffer>) -> Vec<Part> {
    let mut parser = Parser::new(ParseOptions::accepting([1, 2, 3, 4, 5, 6]));
    let mut parts = Vec::new();
    for b in buffers {
        parts.extend(parser.push(b).unwrap());
    }
    parts.extend(parser.finish().unwrap());
    parts
}

#[tokio::test]
async fn the_answer_of_get_service_is_saved_and_read_back_for_a_node() {
    let d = dir();
    let path = d.join("service.bee");
    let content = vec![42u8; 3 * 1024 * 1024];
    let cancel = Cancel::new();
    let bytes = save(stream(get_service_answer(&content)), &path, &cancel).await.unwrap();
    assert_eq!(bytes, std::fs::metadata(&path).unwrap().len());
    assert_eq!(cancel.bytes(), bytes);
    assert!(!d.join("service.bee.partial").exists());

    let info = inspect(&path).await.unwrap();
    assert_eq!(info.layout, Layout::Gateway);
    assert_eq!(info.service_id, Some(SERVICE_ID));
    assert!(info.has_service);
    assert_eq!(info.bytes, bytes);

    let back = collect(read(path, info.layout, Cancel::new())).await.unwrap();
    // The signal of the call is not part of the package.
    assert!(back.iter().all(|b| b.signal.is_none()));
    let parts = parse(back);
    assert_eq!(parts.iter().map(|p| p.index).collect::<Vec<_>>(), [4, 5, 6]);
    let mut expected = b"before".to_vec();
    expected.extend(&content);
    expected.extend(b"after");
    assert!(parts[2].data == expected, "the Service with its block");
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_nodo_export_gets_the_indices_of_start_service() {
    let d = dir();
    let path = d.join("echo.celaut.bee");
    // `nodo export`: Metadata at 1, Service at 2, no hash part.
    let mut file: Vec<Buffer> = serialize_part(&Part::new(1, metadata())).collect();
    file.extend(service_buffers(2, b"the filesystem"));
    let mut raw = Vec::new();
    bee_rpc::bee_file::write_bee(&mut raw, file).unwrap();
    std::fs::write(&path, raw).unwrap();

    let info = inspect(&path).await.unwrap();
    assert_eq!(info.layout, Layout::NodoExport);
    assert_eq!(info.service_id, Some(SERVICE_ID), "from the Metadata");
    assert!(info.has_service);

    let parts = parse(collect(read(path, info.layout, Cancel::new())).await.unwrap());
    assert_eq!(parts.iter().map(|p| p.index).collect::<Vec<_>>(), [5, 6]);
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_node_that_does_not_have_the_service_gives_nothing_and_no_file_stays() {
    let d = dir();
    let path = d.join("none.bee");
    let only_signal = vec![Buffer {
        signal: Some(true),
        ..Default::default()
    }];
    let error = save(stream(only_signal), &path, &Cancel::new()).await.unwrap_err();
    assert!(matches!(error, PackageError::Invalid(_)), "{error}");
    assert!(!path.exists() && !d.join("none.bee.partial").exists());
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn an_error_of_the_node_or_a_cancel_leaves_no_file() {
    let d = dir();
    let path = d.join("cut.bee");
    let mut items: Vec<Result<Buffer, WireError>> =
        get_service_answer(b"x").into_iter().take(4).map(Ok).collect();
    items.push(Err(WireError::Call("the node stopped".into())));
    let error = save(Box::pin(tokio_stream::iter(items)), &path, &Cancel::new())
        .await
        .unwrap_err();
    assert!(matches!(error, PackageError::Wire(_)), "{error}");
    assert!(!path.exists() && !d.join("cut.bee.partial").exists());

    let cancel = Cancel::new();
    cancel.cancel();
    let error = save(stream(get_service_answer(b"x")), &path, &cancel).await.unwrap_err();
    assert!(matches!(error, PackageError::Cancelled), "{error}");
    assert!(!path.exists());
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_cut_file_or_a_cancel_is_an_error_of_the_stream_for_the_node() {
    let d = dir();
    let path = d.join("service.bee");
    save(stream(get_service_answer(&[1u8; 1000])), &path, &Cancel::new()).await.unwrap();
    let full = std::fs::read(&path).unwrap();
    // Cut inside a record, and inside the length of a record.
    for cut in [10, full.len() - 2] {
        std::fs::write(&path, &full[..cut]).unwrap();
        let error = collect(read(path.clone(), Layout::Gateway, Cancel::new()))
            .await
            .unwrap_err();
        assert!(matches!(error, WireError::Relay(ref t) if t.contains("cut")), "{cut}: {error}");
    }

    std::fs::write(&path, &full).unwrap();
    let cancel = Cancel::new();
    cancel.cancel();
    let error = collect(read(path, Layout::Gateway, cancel)).await.unwrap_err();
    assert!(matches!(error, WireError::Relay(ref t) if t.contains("cancel")), "{error}");
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn files_that_are_not_packages_are_refused() {
    let d = dir();
    let empty = d.join("empty.bee");
    std::fs::write(&empty, b"").unwrap();
    assert!(matches!(inspect(&empty).await, Err(PackageError::Invalid(_))));

    let huge = d.join("huge.bee");
    std::fs::write(&huge, u32::MAX.to_be_bytes()).unwrap();
    assert!(matches!(inspect(&huge).await, Err(PackageError::Invalid(_))));

    let garbage = d.join("garbage.bee");
    let mut raw = 5u32.to_be_bytes().to_vec();
    raw.extend([0xff; 5]);
    std::fs::write(&garbage, raw).unwrap();
    assert!(matches!(inspect(&garbage).await, Err(PackageError::Invalid(_))));

    assert!(matches!(inspect(&d.join("missing.bee")).await, Err(PackageError::Io(_))));
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_package_without_the_service_id_says_so() {
    let d = dir();
    let path = d.join("no-id.bee");
    let mut file: Vec<Buffer> = serialize_part(&Part::new(1, Metadata::default().encode_to_vec()))
        .collect();
    file.extend(service_buffers(2, b"fs"));
    let mut raw = Vec::new();
    bee_rpc::bee_file::write_bee(&mut raw, file).unwrap();
    std::fs::write(&path, raw).unwrap();
    let info = inspect(&path).await.unwrap();
    assert_eq!(info.service_id, None);
    assert!(info.has_service);
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_package_is_loaded_into_the_library_under_its_service_id() {
    use celaut_client::package::{import, library_path};
    let d = dir();
    let source = d.join("picked.bee");
    let content = vec![5u8; 2 * 1024 * 1024];
    let id = id_of(&service_buffers(6, &content));
    save(stream(answer_for(&content, id)), &source, &Cancel::new()).await.unwrap();
    let size = std::fs::metadata(&source).unwrap().len();

    let imported = import(&source, &d, &Cancel::new()).await.unwrap();
    assert_eq!(imported.service_id, id);
    assert_eq!(imported.path, library_path(&d, &id));
    assert_eq!(imported.path, d.join("packages/library").join(format!("{}.bee", hex::encode(id))));
    assert_eq!(imported.info.bytes, size);
    // Moved, not copied: the picked file is gone and the library holds all of it.
    assert!(!source.exists());
    assert_eq!(std::fs::metadata(&imported.path).unwrap().len(), size);
    assert!(!d.join("packages/library").join("1111.partial").exists());
    // What is in the library can be read for a node.
    let parts = parse(collect(read(imported.path.clone(), imported.info.layout, Cancel::new())).await.unwrap());
    assert_eq!(parts.iter().map(|p| p.index).collect::<Vec<_>>(), [4, 5, 6]);
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_nodo_export_is_loaded_and_a_second_load_of_the_same_service_replaces_it() {
    use celaut_client::package::import;
    let d = dir();
    let make = |name: &str, pieces: usize| {
        let path = d.join(name);
        // Two exports of one service: the same bytes, so the same id, in chunks of another
        // size (`pieces` chunks after the block instead of one), so the files differ.
        let mut service = service_buffers(2, b"the filesystem");
        let end = service.pop().unwrap();
        for _ in 1..pieces {
            service.push(Buffer {
                chunk: Some(Vec::new()),
                ..Default::default()
            });
        }
        service.push(end);
        let id = id_of(&service_buffers(2, b"the filesystem"));
        let mut file: Vec<Buffer> = serialize_part(&Part::new(1, metadata_of(id))).collect();
        file.extend(service);
        let mut raw = Vec::new();
        bee_rpc::bee_file::write_bee(&mut raw, file).unwrap();
        std::fs::write(&path, raw).unwrap();
        path
    };
    let first = import(&make("one.celaut.bee", 1), &d, &Cancel::new()).await.unwrap();
    assert_eq!(first.info.layout, Layout::NodoExport);
    let first_size = std::fs::metadata(&first.path).unwrap().len();
    let second = import(&make("two.celaut.bee", 4), &d, &Cancel::new())
        .await
        .unwrap();
    assert_eq!(second.path, first.path);
    assert!(std::fs::metadata(&second.path).unwrap().len() > first_size, "replaced");
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_file_that_is_not_a_service_is_refused_and_stays_where_it_is() {
    use celaut_client::package::import;
    let d = dir();
    // No service id.
    let no_id = d.join("no-id.bee");
    let mut file: Vec<Buffer> = serialize_part(&Part::new(1, Metadata::default().encode_to_vec())).collect();
    file.extend(service_buffers(2, b"fs"));
    let mut raw = Vec::new();
    bee_rpc::bee_file::write_bee(&mut raw, file).unwrap();
    std::fs::write(&no_id, raw).unwrap();
    let error = import(&no_id, &d, &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains("which service")), "{error}");
    assert!(no_id.exists());

    // No Service part: only the Metadata.
    let only_metadata = d.join("meta.bee");
    let mut raw = Vec::new();
    bee_rpc::bee_file::write_bee(&mut raw, serialize_part(&Part::new(1, metadata()))).unwrap();
    std::fs::write(&only_metadata, raw).unwrap();
    let error = import(&only_metadata, &d, &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains("no Service")), "{error}");

    // Not a .bee file at all, and a missing file.
    let junk = d.join("junk.bee");
    std::fs::write(&junk, b"hello, this is text").unwrap();
    assert!(import(&junk, &d, &Cancel::new()).await.is_err());
    assert!(junk.exists());
    assert!(matches!(import(&d.join("missing.bee"), &d, &Cancel::new()).await, Err(PackageError::Io(_))));
    assert!(!d.join("packages/library").exists() || std::fs::read_dir(d.join("packages/library")).unwrap().count() == 0);
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn removing_a_package_file_that_is_gone_is_not_an_error() {
    use celaut_client::package::remove_file;
    let d = dir();
    let path = d.join("x.bee");
    std::fs::write(&path, b"x").unwrap();
    remove_file(&path).await.unwrap();
    assert!(!path.exists());
    remove_file(&path).await.unwrap();
    std::fs::remove_dir_all(d).unwrap();
}

/// A nodo export with `service` as its Service part, at `d/name`.
/// The Metadata names the service that the Service hashes to, so only its blocks can be
/// wrong.
fn export_file(d: &std::path::Path, name: &str, service: Vec<Buffer>) -> PathBuf {
    export_file_of(d, name, service.clone(), id_of(&service))
}

/// A nodo export whose Metadata names the service `id`.
fn export_file_of(d: &std::path::Path, name: &str, service: Vec<Buffer>, id: [u8; 32]) -> PathBuf {
    let path = d.join(name);
    let mut file: Vec<Buffer> = serialize_part(&Part::new(1, metadata_of(id))).collect();
    file.extend(service);
    let mut raw = Vec::new();
    bee_rpc::bee_file::write_bee(&mut raw, file).unwrap();
    std::fs::write(&path, raw).unwrap();
    path
}

#[tokio::test]
async fn a_package_with_a_block_that_is_not_its_id_is_refused_and_stays_where_it_is() {
    use celaut_client::package::{import, check_file};
    let d = dir();
    let mut service = service_buffers(2, b"the filesystem");
    service[2].chunk = Some(b"another filesystem".to_vec());
    let path = export_file(&d, "bad.celaut.bee", service);
    let id = hex::encode(HashAlgorithm::Sha3_256.digest(b"the filesystem"));
    let error = check_file(&path, &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains(&id)), "{error}");
    let error = import(&path, &d, &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains("holds other bytes")), "{error}");
    assert!(path.exists());
    assert!(!d.join("packages/library").exists() || std::fs::read_dir(d.join("packages/library")).unwrap().count() == 0);
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_block_inside_a_block_counts_in_the_id_of_both() {
    use celaut_client::package::check_file;
    let d = dir();
    let marker = |id: &[u8]| Buffer {
        block: Some(block_pointer(id, HashAlgorithm::Sha3_256, false)),
        ..Default::default()
    };
    let chunk = |c: &[u8]| Buffer {
        chunk: Some(c.to_vec()),
        ..Default::default()
    };
    let inner = HashAlgorithm::Sha3_256.digest(b"inner");
    let outer = HashAlgorithm::Sha3_256.digest(b"a-inner-b");
    let service = |outer: &[u8]| {
        vec![
            Buffer {
                head: Some(Head { index: 2, partitions: vec![] }),
                ..Default::default()
            },
            marker(outer),
            chunk(b"a-"),
            marker(&inner),
            chunk(b"inner"),
            marker(&inner),
            chunk(b"-b"),
            marker(outer),
            Buffer {
                separator: Some(true),
                ..Default::default()
            },
        ]
    };
    let checked = check_file(&export_file(&d, "nested.celaut.bee", service(&outer)), &Cancel::new()).await.unwrap();
    assert_eq!(checked.service_id, id_of(&service(&outer)));
    // An id that leaves out the block inside it is not the id of the outer block.
    let flat = HashAlgorithm::Sha3_256.digest(b"a--b");
    let error = check_file(&export_file(&d, "flat.celaut.bee", service(&flat)), &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains(&hex::encode(&flat))), "{error}");
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_package_cut_inside_a_block_is_refused() {
    use celaut_client::package::check_file;
    let d = dir();
    let mut service = service_buffers(2, b"the filesystem");
    service.truncate(3);
    let error = check_file(&export_file(&d, "cut.celaut.bee", service), &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains("cut inside")), "{error}");
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn the_check_counts_the_bytes_it_read_and_a_cancel_stops_it() {
    use celaut_client::package::check_file;
    let d = dir();
    let path = export_file(&d, "ok.celaut.bee", service_buffers(2, &vec![9u8; 100_000]));
    let size = std::fs::metadata(&path).unwrap().len();
    let cancel = Cancel::new();
    check_file(&path, &cancel).await.unwrap();
    // Every byte of the file: the progress ends at the size.
    assert_eq!(cancel.bytes(), size);

    let stopped = Cancel::new();
    stopped.cancel();
    let error = check_file(&path, &stopped).await.unwrap_err();
    assert!(matches!(error, PackageError::Cancelled), "{error}");
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_picked_file_whose_service_does_not_hash_to_its_id_is_refused_and_stays_where_it_is() {
    // Issue #135, answer 1: a picked file is checked as a download is, whole Service included.
    use celaut_client::package::{check_file, import};
    let d = dir();
    let service = service_buffers(2, b"the filesystem");
    // Each block holds what its id names, but the Metadata names another service.
    let path = export_file_of(&d, "other.celaut.bee", service.clone(), SERVICE_ID);
    let error = check_file(&path, &Cancel::new()).await.unwrap_err();
    let want = format!("the Service hashes to {}, not to the id {}", hex::encode(id_of(&service)), hex::encode(SERVICE_ID));
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains(&want)), "{error}");
    let error = import(&path, &d, &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains("the Service hashes to")), "{error}");
    assert!(path.exists());
    assert!(!d.join("packages/library").exists() || std::fs::read_dir(d.join("packages/library")).unwrap().count() == 0);
    std::fs::remove_dir_all(d).unwrap();
}
