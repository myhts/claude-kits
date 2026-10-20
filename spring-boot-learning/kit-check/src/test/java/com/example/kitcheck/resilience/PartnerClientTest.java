package com.example.kitcheck.resilience;

import com.sun.net.httpserver.HttpServer;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.retry.Retry;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.ResourceAccessException;

import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Timeouts, breaker and retries against a real (local) slow partner. */
class PartnerClientTest {

    HttpServer partner;
    final AtomicInteger hits = new AtomicInteger();
    volatile long delayMs;

    @BeforeEach
    void start() throws Exception {
        partner = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        partner.createContext("/quotes", ex -> {
            hits.incrementAndGet();
            try { Thread.sleep(delayMs); } catch (InterruptedException ignored) { }
            byte[] body = "42".getBytes(StandardCharsets.UTF_8);
            ex.sendResponseHeaders(200, body.length);
            ex.getResponseBody().write(body);
            ex.close();
        });
        partner.setExecutor(java.util.concurrent.Executors.newCachedThreadPool());
        partner.start();
    }

    @AfterEach
    void stop() {
        partner.stop(0);
    }

    PartnerClient client(CircuitBreaker breaker, Retry retry) {
        return new PartnerClient("http://127.0.0.1:" + partner.getAddress().getPort(), Duration.ofMillis(200), Duration.ofMillis(150), breaker, retry);
    }

    @Test
    void aTimeoutBoundsTheWait() {
        delayMs = 2_000;
        PartnerClient c = client(PartnerClient.breaker("t", false), Retry.ofDefaults("none"));
        long start = System.nanoTime();
        assertThatThrownBy(() -> c.quote("q1")).isInstanceOf(ResourceAccessException.class);
        assertThat(Duration.ofNanos(System.nanoTime() - start)).isLessThan(Duration.ofMillis(1_500));   // ~3 × 150 ms, not 2 s
    }

    @Test
    void retriesAreCountedByTheBreakerAndStopWhenItOpens() {
        delayMs = 2_000;
        CircuitBreaker breaker = PartnerClient.breaker("p", false);
        PartnerClient c = client(breaker, PartnerClient.retry("p"));

        assertThatThrownBy(() -> c.quote("a")).isInstanceOf(ResourceAccessException.class);   // 3 attempts
        assertThat(breaker.getMetrics().getNumberOfFailedCalls()).isEqualTo(3);
        assertThatThrownBy(() -> c.quote("b")).isInstanceOf(CallNotPermittedException.class); // attempt 5 opened it
        assertThat(breaker.getState()).isEqualTo(CircuitBreaker.State.OPEN);

        int before = hits.get();
        long start = System.nanoTime();
        assertThatThrownBy(() -> c.quote("c")).isInstanceOf(CallNotPermittedException.class); // not retried, partner not called
        assertThat(hits.get()).isEqualTo(before);
        assertThat(Duration.ofNanos(System.nanoTime() - start)).isLessThan(Duration.ofMillis(50));
    }

    @Test
    void withoutTrafficTheBreakerStaysOpenUnlessTheTimerIsOn() throws Exception {
        CircuitBreaker lazy = PartnerClient.breaker("lazy", false);
        CircuitBreaker timer = PartnerClient.breaker("timer", true);
        for (CircuitBreaker b : new CircuitBreaker[] {lazy, timer}) b.transitionToOpenState();

        Thread.sleep(600);   // twice waitDurationInOpenState, and no calls at all

        assertThat(lazy.getState()).isEqualTo(CircuitBreaker.State.OPEN);        // moves only when a call arrives
        assertThat(timer.getState()).isEqualTo(CircuitBreaker.State.HALF_OPEN);   // moved by itself
    }

    @Test
    void aHealthyPartnerAnswers() {
        delayMs = 0;
        assertThat(client(PartnerClient.breaker("ok", false), PartnerClient.retry("ok")).quote("q")).isEqualTo("42");
    }
}
