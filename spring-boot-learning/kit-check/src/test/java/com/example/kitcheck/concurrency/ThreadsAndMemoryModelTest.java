package com.example.kitcheck.concurrency;

import org.junit.jupiter.api.Test;

import java.net.ServerSocket;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

/** Proves section 1 of the java-concurrency skill: thread states and the visibility rules it states. */
class ThreadsAndMemoryModelTest {

    private static void awaitState(Thread t, Thread.State state) {
        await().atMost(Duration.ofSeconds(5)).until(t::getState, s -> s == state);
    }

    @Test
    void newThenTerminated() throws InterruptedException {
        Thread t = new Thread(() -> { });
        assertThat(t.getState()).isEqualTo(Thread.State.NEW);
        t.start();
        t.join();
        assertThat(t.getState()).isEqualTo(Thread.State.TERMINATED);
    }

    @Test
    void blockedOnlyOnAMonitorAndKeepsLocksItHolds() throws InterruptedException {
        Object a = new Object(), b = new Object();
        Thread holder = new Thread(() -> { synchronized (a) { synchronized (b) { } } });
        Thread other = new Thread(() -> { synchronized (a) { } });
        synchronized (b) {
            holder.start();
            awaitState(holder, Thread.State.BLOCKED);
            other.start();
            awaitState(other, Thread.State.BLOCKED);   // holder still holds a while blocked on b
        }
        holder.join();
        other.join();
    }

    @Test
    void joinWithoutTimeoutIsWaiting() throws InterruptedException {
        CountDownLatch release = new CountDownLatch(1);
        Thread worker = new Thread(() -> { try { release.await(); } catch (InterruptedException ignored) { } });
        Thread joiner = new Thread(() -> { try { worker.join(); } catch (InterruptedException ignored) { } });
        worker.start();
        joiner.start();
        awaitState(joiner, Thread.State.WAITING);
        release.countDown();
        joiner.join();
    }

    @Test
    void sleepIsTimedWaitingAndKeepsTheMonitor() throws InterruptedException {
        Object lock = new Object();
        Thread sleeper = new Thread(() -> {
            synchronized (lock) { try { Thread.sleep(10_000); } catch (InterruptedException ignored) { } }
        });
        Thread other = new Thread(() -> { synchronized (lock) { } });
        sleeper.start();
        awaitState(sleeper, Thread.State.TIMED_WAITING);
        other.start();
        awaitState(other, Thread.State.BLOCKED);
        sleeper.interrupt();
        sleeper.join();
        other.join();
    }

    @Test
    void waitReleasesOnlyTheMonitorItWaitsOn() throws InterruptedException {
        Object outer = new Object(), inner = new Object();
        Thread waiter = new Thread(() -> {
            synchronized (outer) {
                synchronized (inner) { try { inner.wait(); } catch (InterruptedException ignored) { } }
            }
        });
        Thread wantsOuter = new Thread(() -> { synchronized (outer) { } });
        waiter.start();
        awaitState(waiter, Thread.State.WAITING);
        synchronized (inner) { }                       // inner was released by wait()...
        wantsOuter.start();
        awaitState(wantsOuter, Thread.State.BLOCKED);  // ...but outer was not
        synchronized (inner) { inner.notifyAll(); }
        waiter.join();
        wantsOuter.join();
    }

    @Test
    void blockingIoIsRunnable() throws Exception {
        try (ServerSocket server = new ServerSocket(0)) {
            Thread acceptor = new Thread(() -> { try { server.accept(); } catch (Exception ignored) { } });
            acceptor.start();
            await().pollDelay(Duration.ofMillis(200)).until(() -> true);
            assertThat(acceptor.getState()).isEqualTo(Thread.State.RUNNABLE);
        }
    }

    @Test
    void synchronizedCounterIsExactUnderContention() throws InterruptedException {
        class Counter { long n; synchronized void inc() { n++; } synchronized long get() { return n; } }
        Counter c = new Counter();
        CountDownLatch go = new CountDownLatch(1);
        List<Thread> threads = new ArrayList<>();
        for (int t = 0; t < 8; t++) {
            threads.add(Thread.ofPlatform().start(() -> {
                try { go.await(); } catch (InterruptedException e) { return; }
                for (int i = 0; i < 1_000_000; i++) c.inc();
            }));
        }
        go.countDown();
        for (Thread t : threads) t.join();
        assertThat(c.get()).isEqualTo(8_000_000);
    }

    static volatile boolean stop;

    @Test
    void aVolatileFlagIsSeenByASpinningThread() throws InterruptedException {
        stop = false;
        Thread spinner = Thread.ofPlatform().daemon().start(() -> { while (!stop) { Thread.onSpinWait(); } });
        Thread.sleep(300);                             // let the loop get hot
        stop = true;
        spinner.join(Duration.ofSeconds(2));
        assertThat(spinner.isAlive()).isFalse();
    }

    @Test
    void joinPublishesEverythingTheThreadWrote() throws InterruptedException {
        int[] plain = new int[3];                       // plain, non-volatile writes
        Thread writer = new Thread(() -> { plain[0] = 1; plain[1] = 2; plain[2] = 3; });
        writer.start();
        writer.join();                                  // the join edge: all of writer's writes are visible now
        assertThat(plain).containsExactly(1, 2, 3);
    }
}
