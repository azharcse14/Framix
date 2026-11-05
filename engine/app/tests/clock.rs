//! The real playback clock (P1-061) counts ticks of wall time, monotonic and exact.

use std::time::{Duration, Instant};

use framix_app::clock::{Clock, SystemClock};
use framix_core::time::TICKS_PER_SECOND;

#[test]
fn counts_elapsed_wall_time_in_ticks() {
    let clock = SystemClock::new();
    // The Instants bracket the clock reads, so a preempted thread can't make ticks outgrow
    // the wall time measured around them.
    let start = Instant::now();
    let before = clock.now();
    std::thread::sleep(Duration::from_millis(50));
    let after = clock.now();
    let elapsed = start.elapsed();
    let ticks = after.0 - before.0;
    let ms = |t: i64| t * 1000 / TICKS_PER_SECOND;
    assert!(ms(ticks) >= 50, "{} ms", ms(ticks));
    assert!(
        ms(ticks) <= elapsed.as_millis() as i64,
        "{} ms in {elapsed:?}",
        ms(ticks)
    );
    assert!(clock.now() >= before, "never goes back");
}
