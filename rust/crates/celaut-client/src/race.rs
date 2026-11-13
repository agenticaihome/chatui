//! Race the addresses of one node (`docs/celaut/invite.md`, section 3; issue #139).
//!
//! A node can have several addresses. Tried one after another, an address that hangs
//! makes the user wait for its whole timeout before the next one is tried. [`race`]
//! starts the first [`WIDTH`] attempts at the same time and uses the first that works:
//!
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

/// How many attempts run at the same time.
pub const WIDTH: usize = 2;

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
/// attempt of address `i`. At most `width` (at least 1) run at once. The result has one
/// [`Outcome`] for each address, in the same order; at most one is [`Outcome::Won`].
///
/// With `width` 1 this is the old way: one after another, the first that works.
pub async fn race<T, E, F, Fut>(
    count: usize,
    width: usize,
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
    // The best attempt that worked so far: the earliest in the order.
    let mut best: Option<(usize, T)> = None;
    let mut deadline: Option<tokio::time::Instant> = None;
    loop {
        match &best {
            // Nothing worked yet: keep `width` attempts running.
            None => {
                while running.len() < width && next < count {
                    let i = next;
                    next += 1;
                    running_now[i] = true;
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
        let done = match deadline {
            None => running.next().await,
            Some(d) => tokio::select! {
                biased;
                r = running.next() => r,
                _ = tokio::time::sleep_until(d) => None,
            },
        };
        // `None`: the grace is over (the set is not empty).
        let Some((i, result)) = done else {
            break;
        };
        running_now[i] = false;
        match result {
            Ok(t) => match &best {
                Some((b, _)) if *b < i => outcomes[i] = Outcome::Unused(t),
                _ => {
                    if let Some((old, v)) = best.replace((i, t)) {
                        outcomes[old] = Outcome::Unused(v);
                    }
                    if deadline.is_none() {
                        deadline = Some(tokio::time::Instant::now() + grace);
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

    async fn run(fakes: &[Fake], width: usize, probe: &Probe) -> Vec<Outcome<usize, usize>> {
        race(fakes.len(), width, GRACE, |i| {
            let fake = fakes[i];
            async move {
                let n = probe.now.fetch_add(1, Ordering::SeqCst) + 1;
                probe.most.fetch_max(n, Ordering::SeqCst);
                probe.started.lock().unwrap().push(i);
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
    async fn a_slow_first_address_does_not_hold_up_a_fast_second_one() {
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Hangs, Fake::Ok(100)], WIDTH, &probe).await;
        // The second answered at 100 ms; the first had the grace, then was stopped.
        assert_eq!(got, vec![Outcome::Stopped, Outcome::Won(1)]);
        assert_eq!(t0.elapsed(), Duration::from_millis(100) + GRACE);
        assert_eq!(*probe.dropped.lock().unwrap(), vec![0]);
        assert_eq!(probe.now.load(Ordering::SeqCst), 0);
    }

    #[tokio::test(start_paused = true)]
    async fn a_slow_first_address_that_times_out_lets_the_fast_one_win() {
        // Like a node whose first address waits for the whole 10-second timeout.
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Err(10_000), Fake::Ok(30)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Stopped, Outcome::Won(1)]);
        assert!(t0.elapsed() < Duration::from_secs(1));
        // One after another, the same addresses took the whole timeout first.
        let t0 = Instant::now();
        let got = run(&[Fake::Err(10_000), Fake::Ok(30)], 1, &Probe::default()).await;
        assert_eq!(got, vec![Outcome::Failed(0), Outcome::Won(1)]);
        assert_eq!(t0.elapsed(), Duration::from_millis(10_030));
    }

    #[tokio::test(start_paused = true)]
    async fn the_preferred_address_wins_when_both_answer_at_nearly_the_same_time() {
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Ok(120), Fake::Ok(100)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Won(0), Outcome::Unused(1)]);
        // No wait for the grace once the first in the order answered.
        assert_eq!(t0.elapsed(), Duration::from_millis(120));
        assert!(probe.dropped.lock().unwrap().is_empty());
    }

    #[tokio::test(start_paused = true)]
    async fn the_preferred_address_loses_when_it_answers_after_the_grace() {
        let probe = Probe::default();
        let later = GRACE.as_millis() as u64 + 101;
        let got = run(&[Fake::Ok(later), Fake::Ok(100)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Stopped, Outcome::Won(1)]);
    }

    #[tokio::test(start_paused = true)]
    async fn a_later_address_that_works_is_used_at_once_and_the_rest_is_stopped() {
        // The first works: the second, which still runs, is stopped without the grace.
        let probe = Probe::default();
        let t0 = Instant::now();
        let got = run(&[Fake::Ok(10), Fake::Hangs, Fake::Ok(1)], WIDTH, &probe).await;
        assert_eq!(
            got,
            vec![Outcome::Won(0), Outcome::Stopped, Outcome::NotStarted]
        );
        assert_eq!(t0.elapsed(), Duration::from_millis(10));
        assert_eq!(*probe.started.lock().unwrap(), vec![0, 1]);
        assert_eq!(*probe.dropped.lock().unwrap(), vec![1]);
    }

    #[tokio::test(start_paused = true)]
    async fn never_more_than_two_at_a_time_and_a_failure_starts_the_next() {
        let probe = Probe::default();
        let fakes = [
            Fake::Err(50),
            Fake::Err(10),
            Fake::Err(5),
            Fake::Err(100),
            Fake::Ok(20),
            Fake::Ok(1),
        ];
        let got = run(&fakes, WIDTH, &probe).await;
        assert_eq!(probe.most.load(Ordering::SeqCst), 2);
        // 1 fails at 10 → 2 starts, fails at 15 → 3 starts; 0 fails at 50 → 4 starts and
        // works at 70. 3 is before 4 in the order and fails at 115, in the grace; 5 never
        // starts.
        assert_eq!(*probe.started.lock().unwrap(), vec![0, 1, 2, 3, 4]);
        assert_eq!(
            got,
            vec![
                Outcome::Failed(0),
                Outcome::Failed(1),
                Outcome::Failed(2),
                Outcome::Failed(3),
                Outcome::Won(4),
                Outcome::NotStarted,
            ]
        );
    }

    #[tokio::test(start_paused = true)]
    async fn when_nothing_works_every_address_fails_in_order() {
        let probe = Probe::default();
        let got = run(&[Fake::Err(30), Fake::Err(10), Fake::Err(20)], WIDTH, &probe).await;
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
        let got = run(&[Fake::Err(150), Fake::Ok(100)], WIDTH, &probe).await;
        assert_eq!(got, vec![Outcome::Failed(0), Outcome::Won(1)]);
        // Done as soon as the earlier one failed, before the end of the grace.
        assert_eq!(t0.elapsed(), Duration::from_millis(150));
    }
}
