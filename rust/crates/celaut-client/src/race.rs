//! Race the addresses of one node (`docs/celaut/invite.md`, section 3.1; issue #139).
//!
//! A node can have several addresses. Tried one after another, an address that hangs
//! makes the user wait for its whole timeout before the next one is tried. [`race`]
//! staggers the attempts as Happy Eyeballs does (RFC 8305) and uses the first that works:
//!
//! - The first address starts alone. It has [`HEAD_START`]: the next address starts when
//!   the head start is over or when the first fails, whichever comes first. So a healthy
//!   first address is the only one that is dialed. The same holds between each attempt
//!   and the next.
//! - At most [`WIDTH`] attempts run at once. When one fails, the next address starts.
//! - When an attempt works, no new one starts. The attempts after it in the order of
//!   preference are stopped at once.
//! - An attempt before it in the order may still be running. It gets [`GRACE`] more: if it
//!   works in that time, it is used instead, so the order of preference is kept when two
//!   addresses answer at nearly the same time. After that it is stopped.
//!
//! An attempt is stopped by dropping its future, so it must not leave a half-made state
//! that matters behind.

use std::future::Future;
use std::time::Duration;

use futures::stream::{FuturesUnordered, StreamExt};
use tokio::time::Instant;

/// How many attempts run at the same time.
pub const WIDTH: usize = 2;

/// How long an attempt runs alone before the next address starts, unless it fails
/// first (the "Connection Attempt Delay" of RFC 8305).
pub const HEAD_START: Duration = Duration::from_millis(250);

/// How long an address earlier in the order can still win after a later one worked.
pub const GRACE: Duration = Duration::from_millis(250);

/// What happened with one address.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome<T, E> {
    /// Not started: an earlier address worked first, or there were no more to try.
    NotStarted,
    /// The attempt ended with this error.
    Failed(E),
    /// Started, then stopped because another address worked.
    Stopped,
    /// It worked, but an address earlier in the order worked too and is used.
    Unused(T),
    /// The address that is used.
    Won(T),
}

impl<T, E> Outcome<T, E> {
    /// Whether this attempt was started (every outcome but [`Outcome::NotStarted`]).
    pub fn started(&self) -> bool {
        !matches!(self, Outcome::NotStarted)
    }
}

/// Race `count` attempts, in the order of preference `0..count`: `attempt(i)` makes the
/// attempt of address `i`. At most `width` (at least 1) run at once, and each attempt
/// starts `head_start` after the one before it, or at once when that one has ended. The
/// result has one [`Outcome`] for each address, in the same order; at most one is
/// [`Outcome::Won`].
///
/// With `width` 1 this is the old way: one after another, the first that works. With a
/// `head_start` of zero the first `width` attempts start together.
pub async fn race<T, E, F, Fut>(
    count: usize,
    width: usize,
    head_start: Duration,
    grace: Duration,
    attempt: F,
) -> Vec<Outcome<T, E>>
where
    F: Fn(usize) -> Fut,
    Fut: Future<Output = Result<T, E>>,
{
    let width = width.max(1);
    let mut outcomes: Vec<Outcome<T, E>> = (0..count).map(|_| Outcome::NotStarted).collect();
    let mut running_now = vec![false; count];
    let mut running = FuturesUnordered::new();
    let mut next = 0;
    // The last attempt that started, and when the next one may start while it runs.
    let mut stagger: Option<(usize, Instant)> = None;
    // The best attempt that worked so far: the earliest in the order.
    let mut best: Option<(usize, T)> = None;
    let mut deadline: Option<Instant> = None;
    loop {
        // When the next address may start, if one can start at all.
        let mut start_at: Option<Instant> = None;
        match &best {
            // Nothing worked yet: start the next attempts that may start now.
            None => {
                while running.len() < width && next < count {
                    let now = Instant::now();
                    if let Some((_, at)) = stagger.filter(|(_, at)| *at > now) {
                        start_at = Some(at);
                        break;
                    }
                    let i = next;
                    next += 1;
                    running_now[i] = true;
                    stagger = Some((i, now + head_start));
                    let fut = attempt(i);
                    running.push(async move { (i, fut.await) });
                }
            }
            // Something worked: wait only for the attempts before it.
            Some((b, _)) => {
                if !running_now[..*b].iter().any(|r| *r) {
                    break;
                }
            }
        }
        if running.is_empty() {
            break;
        }
        // `None` from a timer: the grace is over, or the next address may start.
        let wake = match (deadline, start_at) {
            (Some(d), _) => Some((d, true)),
            (None, Some(s)) => Some((s, false)),
            (None, None) => None,
        };
        let done = match wake {
            None => running.next().await,
            Some((at, _)) => tokio::select! {
                biased;
                r = running.next() => r,
                _ = tokio::time::sleep_until(at) => None,
            },
        };
        let Some((i, result)) = done else {
            match wake {
                // The grace is over (the set is not empty).
                Some((_, true)) => break,
                // The head start is over: the loop starts the next address.
                _ => continue,
            }
        };
        running_now[i] = false;
        // The last attempt that started has ended: the next may start at once.
        if stagger.is_some_and(|(last, _)| last == i) {
            stagger = None;
        }
        match result {
            Ok(t) => match &best {
                Some((b, _)) if *b < i => outcomes[i] = Outcome::Unused(t),
                _ => {
                    if let Some((old, v)) = best.replace((i, t)) {
                        outcomes[old] = Outcome::Unused(v);
                    }
                    if deadline.is_none() {
                        deadline = Some(Instant::now() + grace);
                    }
                }
            },
            Err(e) => outcomes[i] = Outcome::Failed(e),
        }
    }
    // Stop what still runs.
    drop(running);
    for (i, r) in running_now.iter().enumerate() {
        if *r {
            outcomes[i] = Outcome::Stopped;
        }
    }
    if let Some((b, t)) = best {
        outcomes[b] = Outcome::Won(t);
    }
    outcomes
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Mutex;
    use tokio::time::{sleep, Instant};

    /// An address that answers `Ok(i)` or `Err(i)` after some milliseconds, or never.
    #[derive(Clone, Copy)]
    enum Fake {
        Ok(u64),
        Err(u64),
        Hangs,
    }

    /// Counts the attempts that run now and the most that ran at once, and marks the
    /// attempts whose future was dropped before it ended.
    #[derive(Default)]
    struct Probe {
        now: AtomicUsize,
        most: AtomicUsize,
        started: Mutex<Vec<usize>>,
        /// When each attempt started, in milliseconds from the start of the race.
        at: Mutex<Vec<u64>>,
        dropped: Mutex<Vec<usize>>,
    }

    struct Running<'a> {
        probe: &'a Probe,
        i: usize,
        ended: bool,
    }

    impl Drop for Running<'_> {
        fn drop(&mut self) {
            self.probe.now.fetch_sub(1, Ordering::SeqCst);
            if !self.ended {
                self.probe.dropped.lock().unwrap().push(self.i);
            }
        }
    }

    fn ms_since(t0: Instant) -> u64 {
        t0.elapsed().as_millis() as u64
    }

    const H: u64 = HEAD_START.as_millis() as u64;
    const G: u64 = GRACE.as_millis() as u64;

    async fn run(fakes: &[Fake], width: usize, probe: &Probe) -> Vec<Outcome<usize, usize>> {
        run_with(fakes, width, HEAD_START, probe).await
    }

    async fn run_with(
        fakes: &[Fake],
        width: usize,
        head_start: Duration,
        probe: &Probe,
    ) -> Vec<Outcome<usize, usize>> {
        let t0 = Instant::now();
        race(fakes.len(), width, head_start, GRACE, |i| {
            let fake = fakes[i];
            async move {
                let n = probe.now.fetch_add(1, Ordering::SeqCst) + 1;
                probe.most.fetch_max(n, Ordering::SeqCst);
                probe.started.lock().unwrap().push(i);
                probe.at.lock().unwrap().push(ms_since(t0));
                let mut guard = Running {
                    probe,
                    i,
                    ended: false,
                };
                let r = match fake {
                    Fake::Ok(ms) => {
                        sleep(Duration::from_millis(ms)).await;
                        Ok(i)
                    }
                    Fake::Err(ms) => {
                        sleep(Duration::from_millis(ms)).await;
                        Err(i)
                    }
                    Fake::Hangs => futures::future::pending().await,
                };
                guard.ended = true;
                r
            }
        })
        .await
    }

    #[tokio::test(start_paused = true)]
    async fn a_healthy_first_address_is_the_only_one_dialed() {
        // It answers within its head start: the second address never starts.
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Ok(100), Fake::Ok(1)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Won(0), Outcome::NotStarted]);
        assert_eq!(ms_since(t0), 100);
        assert_eq!(*probe.started.lock().unwrap(), vec![0]);
        assert_eq!(probe.most.load(Ordering::SeqCst), 1);
    }

    #[tokio::test(start_paused = true)]
    async fn the_second_address_starts_when_the_head_start_is_over() {
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Hangs, Fake::Ok(100)], WIDTH, &probe).await;
        // The second started at the end of the head start and answered 100 ms later; the
        // first had the grace, then was stopped.
        assert_eq!(got, vec![Outcome::Stopped, Outcome::Won(1)]);
        assert_eq!(*probe.at.lock().unwrap(), vec![0, H]);
        assert_eq!(ms_since(t0), H + 100 + G);
        assert_eq!(*probe.dropped.lock().unwrap(), vec![0]);
        assert_eq!(probe.now.load(Ordering::SeqCst), 0);
    }

    #[tokio::test(start_paused = true)]
    async fn a_first_address_that_fails_early_starts_the_second_at_once() {
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Err(50), Fake::Ok(10)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Failed(0), Outcome::Won(1)]);
        assert_eq!(*probe.at.lock().unwrap(), vec![0, 50]);
        assert_eq!(ms_since(t0), 60);
    }

    #[tokio::test(start_paused = true)]
    async fn without_a_head_start_the_first_two_start_together() {
        let probe = Probe::default();
        let got = run_with(&[Fake::Hangs, Fake::Ok(100)], WIDTH, Duration::ZERO, &probe).await;
        assert_eq!(got, vec![Outcome::Stopped, Outcome::Won(1)]);
        assert_eq!(*probe.at.lock().unwrap(), vec![0, 0]);
    }

    #[tokio::test(start_paused = true)]
    async fn a_slow_first_address_that_times_out_lets_the_fast_one_win() {
        // Like a node whose first address waits for the whole 10-second timeout.
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Err(10_000), Fake::Ok(30)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Stopped, Outcome::Won(1)]);
        assert_eq!(ms_since(t0), H + 30 + G);
        // One after another, the same addresses took the whole timeout first.
        let t0 = Instant::now();
        let got = run(&[Fake::Err(10_000), Fake::Ok(30)], 1, &Probe::default()).await;
        assert_eq!(got, vec![Outcome::Failed(0), Outcome::Won(1)]);
        assert_eq!(t0.elapsed(), Duration::from_millis(10_030));
    }

    #[tokio::test(start_paused = true)]
    async fn the_preferred_address_wins_when_both_answer_at_nearly_the_same_time() {
        // The second answers at H + 30; the first a little later, within the grace.
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Ok(H + 50), Fake::Ok(30)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Won(0), Outcome::Unused(1)]);
        // No wait for the end of the grace once the first in the order answered.
        assert_eq!(ms_since(t0), H + 50);
        assert!(probe.dropped.lock().unwrap().is_empty());
    }

    #[tokio::test(start_paused = true)]
    async fn the_preferred_address_loses_when_it_answers_after_the_grace() {
        let probe = Probe::default();
        let got = run(&[Fake::Ok(H + 30 + G + 1), Fake::Ok(30)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Stopped, Outcome::Won(1)]);
    }

    #[tokio::test(start_paused = true)]
    async fn a_winner_stops_the_later_attempts_at_once() {
        // The first works while the second still runs: the second is stopped without the
        // grace, and the third never starts.
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(
            &[Fake::Ok(H + 100), Fake::Hangs, Fake::Ok(1)],
            WIDTH,
            &probe,
        )
        .await;
        assert_eq!(
            got,
            vec![Outcome::Won(0), Outcome::Stopped, Outcome::NotStarted]
        );
        assert_eq!(ms_since(t0), H + 100);
        assert_eq!(*probe.started.lock().unwrap(), vec![0, 1]);
        assert_eq!(*probe.dropped.lock().unwrap(), vec![1]);
    }

    #[tokio::test(start_paused = true)]
    async fn never_more_than_two_at_a_time_and_a_failure_starts_the_next() {
        let probe = Probe::default();
        let fakes = [
            Fake::Err(1000),
            Fake::Err(600),
            Fake::Err(5),
            Fake::Ok(20),
            Fake::Ok(1),
        ];
        let got = run(&fakes, WIDTH, &probe).await;
        assert_eq!(probe.most.load(Ordering::SeqCst), 2);
        // 0 at 0; 1 at H (two run, so 2 waits). 1 fails at H + 600 → 2 starts, fails 5 ms
        // later → 3 starts and works 20 ms later. 0 is before 3 in the order and fails at
        // 1000, in the grace; 4 never starts.
        assert_eq!(*probe.started.lock().unwrap(), vec![0, 1, 2, 3]);
        assert_eq!(*probe.at.lock().unwrap(), vec![0, H, H + 600, H + 605]);
        assert_eq!(
            got,
            vec![
                Outcome::Failed(0),
                Outcome::Failed(1),
                Outcome::Failed(2),
                Outcome::Won(3),
                Outcome::NotStarted,
            ]
        );
    }

    #[tokio::test(start_paused = true)]
    async fn each_attempt_has_its_head_start_over_the_next() {
        // The first fails early, so the second starts at once; the second hangs, so the
        // third starts at the end of the head start of the second.
        let probe = Probe::default();
        let got = run(&[Fake::Err(10), Fake::Hangs, Fake::Ok(5)], WIDTH, &probe).await;
        assert_eq!(*probe.at.lock().unwrap(), vec![0, 10, 10 + H]);
        assert_eq!(
            got,
            vec![Outcome::Failed(0), Outcome::Stopped, Outcome::Won(2)]
        );
    }

    #[tokio::test(start_paused = true)]
    async fn when_nothing_works_every_address_fails_in_order() {
        let probe = Probe::default();
        let got = run(
            &[Fake::Err(30), Fake::Err(10), Fake::Err(20)],
            WIDTH,
            &probe,
        )
        .await;
        assert_eq!(
            got,
            vec![Outcome::Failed(0), Outcome::Failed(1), Outcome::Failed(2)]
        );
        assert!(got.iter().all(Outcome::started));
    }

    #[tokio::test(start_paused = true)]
    async fn one_address_and_no_address() {
        let got = run(&[Fake::Ok(5)], WIDTH, &Probe::default()).await;
        assert_eq!(got, vec![Outcome::Won(0)]);
        let got = run(&[], WIDTH, &Probe::default()).await;
        assert!(got.is_empty());
        // A width of 0 is one at a time.
        let probe = Probe::default();
        let got = run(&[Fake::Err(1), Fake::Ok(1)], 0, &probe).await;
        assert_eq!(got, vec![Outcome::Failed(0), Outcome::Won(1)]);
        assert_eq!(probe.most.load(Ordering::SeqCst), 1);
    }

    #[tokio::test(start_paused = true)]
    async fn an_earlier_address_that_fails_in_the_grace_leaves_the_winner() {
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Err(H + 150), Fake::Ok(100)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Failed(0), Outcome::Won(1)]);
        // Done as soon as the earlier one failed, before the end of the grace.
        assert_eq!(ms_since(t0), H + 150);
    }
}
