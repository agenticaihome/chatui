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

/// The records of a `.bee` file as Buffers.
async fn records_of(path: &std::path::Path) -> Vec<Buffer> {
    collect(read(path.to_path_buf(), Layout::Gateway, Cancel::new())).await.unwrap()
}

#[tokio::test]
async fn a_package_can_be_loaded_without_the_content_of_its_blocks() {
    use celaut_client::package::{import_with, library_path, Storage};
    let d = dir();
    let source = d.join("picked.bee");
    let content = vec![5u8; 2 * 1024 * 1024];
    let id = id_of(&service_buffers(6, &content));
    save(stream(answer_for(&content, id)), &source, &Cancel::new()).await.unwrap();
    let size = std::fs::metadata(&source).unwrap().len();

    let imported = import_with(&source, &d, &Cancel::new(), Storage::WithoutFilesystem)
        .await
        .unwrap();
    assert_eq!(imported.service_id, id);
    assert_eq!(imported.path, library_path(&d, &id));
    assert!(!imported.filesystem_kept);
    assert_eq!(imported.info.bytes, size);
    let stored = std::fs::metadata(&imported.path).unwrap().len();
    assert_eq!(imported.stored_bytes, stored);
    assert!(stored < 2_000, "the library file has {stored} bytes of {size}");
    // The picked file is gone, and nothing partial stays.
    assert!(!source.exists());
    assert!(!d.join("packages/library").join(format!("{}.bee.partial", hex::encode(id))).exists());
    // What is outside the block is still there, with the two markers and not the content.
    let all = records_of(&imported.path).await;
    let chunks: Vec<&[u8]> = all.iter().filter_map(|b| b.chunk.as_deref()).collect();
    // (The other chunks are the hash and the Metadata, before the Service.)
    let service_chunks: Vec<&[u8]> = chunks.iter().rev().take(2).rev().copied().collect();
    assert_eq!(service_chunks, [&b"before"[..], &b"after"[..]]);
    assert!(chunks.iter().all(|c| c.len() < 1_000), "the content of the block is in the file");
    assert_eq!(all.iter().filter(|b| b.block.is_some()).count(), 2);
    let info = inspect(&imported.path).await.unwrap();
    assert_eq!(info.service_id, Some(id));
    assert!(info.has_service);
    // Loading the whole file again replaces it.
    save(stream(answer_for(&content, id)), &source, &Cancel::new()).await.unwrap();
    let again = import_with(&source, &d, &Cancel::new(), Storage::Whole).await.unwrap();
    assert!(again.filesystem_kept);
    assert_eq!(std::fs::metadata(&again.path).unwrap().len(), size);
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn without_the_filesystem_the_blocks_inside_a_block_go_too_and_a_false_block_is_still_refused() {
    use celaut_client::package::{import_with, strip_filesystem, Storage};
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
                chunk: Some(b"head".to_vec()),
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
                chunk: Some(b"tail".to_vec()),
                separator: Some(true),
                ..Default::default()
            },
        ]
    };
    let file = export_file(&d, "nested.celaut.bee", service(&outer));
    let imported = import_with(&file, &d, &Cancel::new(), Storage::WithoutFilesystem).await.unwrap();
    let all = records_of(&imported.path).await;
    let chunks: Vec<&[u8]> = all.iter().filter_map(|b| b.chunk.as_deref()).collect();
    for gone in [&b"a-"[..], &b"inner"[..], &b"-b"[..]] {
        assert!(!chunks.contains(&gone), "{:?} is in the file", String::from_utf8_lossy(gone));
    }
    assert!(chunks.contains(&&b"head"[..]) && chunks.contains(&&b"tail"[..]));
    let ids: Vec<Vec<u8>> = all
        .iter()
        .filter_map(|b| b.block.as_ref())
        .map(|b| b.hashes[0].value.clone())
        .collect();
    assert_eq!(ids, [outer.to_vec(), outer.to_vec()]);

    // A block that does not hold its id is refused by the check, before anything is cut.
    let flat = HashAlgorithm::Sha3_256.digest(b"a--b");
    let bad = export_file(&d, "bad.celaut.bee", service(&flat));
    let error = import_with(&bad, &d, &Cancel::new(), Storage::WithoutFilesystem).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(_)), "{error}");
    assert!(bad.exists());

    // A file cut inside a block is an error and leaves no file.
    let mut cut = service(&outer);
    cut.truncate(5);
    let cut = export_file_of(&d, "cut.celaut.bee", cut, [1u8; 32]);
    let target = d.join("stripped.bee");
    let error = strip_filesystem(&cut, &target, &Cancel::new()).await.unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains("cut inside")), "{error}");
    assert!(!target.exists());
    assert!(!d.join("stripped.bee.partial").exists());
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_check_that_stopped_goes_on_from_its_saved_state_at_any_byte() {
    use celaut_client::package::Check;
    let d = dir();
    let content: Vec<u8> = (0..400_000usize).map(|i| (i * 7 % 251) as u8).collect();
    let id = id_of(&service_buffers(6, &content));
    let file = d.join("whole.bee");
    save(stream(answer_for(&content, id)), &file, &Cancel::new()).await.unwrap();
    let bytes = std::fs::read(&file).unwrap();

    // The whole file in one run, for the answer that every split must give.
    let mut straight = Check::stripping();
    let mut want = Vec::new();
    for piece in bytes.chunks(8192) {
        straight.feed(piece).unwrap();
        want.extend(straight.take_output());
    }
    let want_checked = straight.finish().unwrap();
    assert_eq!(want_checked.service_id, id);
    assert!(want.len() < 2_000, "{} bytes of {}", want.len(), bytes.len());

    // Stopped at many points (inside a record, between records, inside a block), saved,
    // restored and finished: the same file and the same result.
    for cut in [1, 3, 4, 5, 100, 1_000, 65_000, 65_537, 131_072, 200_001, bytes.len() - 7, bytes.len()] {
        let mut first = Check::stripping();
        let mut got = Vec::new();
        for piece in bytes[..cut].chunks(8192) {
            first.feed(piece).unwrap();
            got.extend(first.take_output());
        }
        let saved = first.snapshot();
        drop(first);
        let mut second = Check::restore(&saved).unwrap();
        assert_eq!(second.bytes(), cut as u64);
        for piece in bytes[cut..].chunks(5000) {
            second.feed(piece).unwrap();
            got.extend(second.take_output());
        }
        assert_eq!(second.finish().unwrap(), want_checked, "cut at {cut}");
        assert_eq!(got, want, "cut at {cut}");
    }

    // A saved state that is cut or has other bytes is an error, not a panic.
    let mut check = Check::stripping();
    check.feed(&bytes[..70_000]).unwrap();
    let saved = check.snapshot();
    for bad in [&saved[..saved.len() - 1], &saved[..10], &[][..], &[9u8][..]] {
        assert!(Check::restore(bad).is_err());
    }
    let mut long = saved.clone();
    long.push(0);
    assert!(Check::restore(&long).is_err());
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_package_is_loaded_from_a_reader_with_only_the_small_file_on_the_disk() {
    use celaut_client::package::{import_reader, library_path, Storage};
    let d = dir();
    let content = vec![9u8; 3 * 1024 * 1024];
    let id = id_of(&service_buffers(6, &content));
    let source = d.join("source.bee");
    save(stream(answer_for(&content, id)), &source, &Cancel::new()).await.unwrap();
    let bytes = std::fs::read(&source).unwrap();

    // A reader that is not a file on the disk: the bytes come in small pieces.
    let (mut tx, rx) = tokio::io::duplex(10_000);
    let feed = tokio::spawn({
        let bytes = bytes.clone();
        async move {
            use tokio::io::AsyncWriteExt;
            for piece in bytes.chunks(3000) {
                tx.write_all(piece).await.unwrap();
            }
        }
    });
    let cancel = Cancel::new();
    let imported = import_reader(rx, &d, &cancel, Storage::WithoutFilesystem).await.unwrap();
    feed.await.unwrap();
    assert_eq!(imported.service_id, id);
    assert_eq!(imported.path, library_path(&d, &id));
    assert!(!imported.filesystem_kept);
    assert_eq!(imported.info.bytes, bytes.len() as u64);
    assert_eq!(cancel.bytes(), bytes.len() as u64);
    let stored = std::fs::metadata(&imported.path).unwrap().len();
    assert_eq!(imported.stored_bytes, stored);
    assert!(stored < 2_000, "{stored} bytes");
    // The file is the same as the one that `import_with` makes from the file.
    let other = d.join("other");
    let from_file = celaut_client::package::import_with(&source, &other, &Cancel::new(), Storage::WithoutFilesystem)
        .await
        .unwrap();
    assert_eq!(std::fs::read(&from_file.path).unwrap(), std::fs::read(&imported.path).unwrap());
    // Nothing else stays in the library.
    let names: Vec<_> = std::fs::read_dir(d.join("packages/library"))
        .unwrap()
        .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
        .collect();
    assert_eq!(names, [format!("{}.bee", hex::encode(id))]);

    // The whole file also works, byte for byte.
    let whole = import_reader(bytes.as_slice(), &d, &Cancel::new(), Storage::Whole).await.unwrap();
    assert!(whole.filesystem_kept);
    assert_eq!(std::fs::read(&whole.path).unwrap(), bytes);
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn a_reader_that_fails_the_check_or_is_cancelled_leaves_nothing_in_the_library() {
    use celaut_client::package::{import_reader, Storage};
    let d = dir();
    let content = vec![1u8; 500_000];
    let id = id_of(&service_buffers(6, &content));
    let source = d.join("source.bee");
    save(stream(answer_for(&content, id)), &source, &Cancel::new()).await.unwrap();
    let bytes = std::fs::read(&source).unwrap();
    let library = d.join("packages/library");
    let empty = || !library.exists() || std::fs::read_dir(&library).unwrap().count() == 0;

    // A byte of the block changed.
    let mut changed = bytes.clone();
    let at = changed.len() - 100_000;
    changed[at] ^= 1;
    let error = import_reader(changed.as_slice(), &d, &Cancel::new(), Storage::WithoutFilesystem)
        .await
        .unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(t) if t.contains("holds other bytes")), "{error}");
    assert!(empty());
    // Cut.
    let error = import_reader(&bytes[..bytes.len() / 2], &d, &Cancel::new(), Storage::WithoutFilesystem)
        .await
        .unwrap_err();
    assert!(matches!(&error, PackageError::Invalid(_)), "{error}");
    assert!(empty());
    // Cancelled before it starts.
    let cancel = Cancel::new();
    cancel.cancel();
    let error = import_reader(bytes.as_slice(), &d, &cancel, Storage::WithoutFilesystem).await.unwrap_err();
    assert!(matches!(error, PackageError::Cancelled), "{error}");
    assert!(empty());
    std::fs::remove_dir_all(d).unwrap();
}

#[tokio::test]
async fn the_space_of_the_packages_is_read_from_the_files() {
    use celaut_client::package::{storage_usage, StorageUsage};
    let d = dir();
    assert_eq!(storage_usage(&d).await, StorageUsage::default());
    let library = d.join("packages/library");
    let downloads = d.join("packages/downloads/abc");
    let incoming = d.join("packages/incoming");
    for f in [&library, &downloads, &incoming] {
        std::fs::create_dir_all(f).unwrap();
    }
    std::fs::write(library.join("a.bee"), vec![0u8; 1000]).unwrap();
    std::fs::write(library.join("b.bee"), vec![0u8; 24]).unwrap();
    std::fs::write(downloads.join("service.bee.partial"), vec![0u8; 300]).unwrap();
    std::fs::write(downloads.join("state.json"), vec![0u8; 12]).unwrap();
    std::fs::write(incoming.join("picked.bee"), vec![0u8; 5]).unwrap();
    assert_eq!(
        storage_usage(&d).await,
        StorageUsage { library_bytes: 1024, library_files: 2, downloads_bytes: 312, incoming_bytes: 5 }
    );
    std::fs::remove_dir_all(d).unwrap();
}
