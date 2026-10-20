package com.example.kitcheck.resilience;

import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.core.IntervalFunction;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryConfig;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.function.Supplier;

/**
 * Calling a partner the safe way, in order of importance: a timeout on every call, a breaker that stops calling a
 * partner that keeps failing, and a few retries with jittered backoff that never retry an open breaker.
 * Order: Retry(CircuitBreaker(call)): every attempt is counted by the breaker, and an open breaker ends the retries.
 */
public class PartnerClient {

    private final RestClient http;
    private final CircuitBreaker breaker;
    private final Retry retry;

    public PartnerClient(String baseUrl, Duration connectTimeout, Duration readTimeout, CircuitBreaker breaker, Retry retry) {
        HttpClient jdk = HttpClient.newBuilder().connectTimeout(connectTimeout).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(jdk);
        factory.setReadTimeout(readTimeout);   // without this, a hung partner holds the thread forever
        this.http = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
        this.breaker = breaker;
        this.retry = retry;
    }

    public String quote(String id) {
        Supplier<String> call = () -> http.get().uri("/quotes/{id}", id).retrieve().body(String.class);
        return Retry.decorateSupplier(retry, CircuitBreaker.decorateSupplier(breaker, call)).get();
    }

    public static CircuitBreaker breaker(String name, boolean automaticHalfOpen) {
        return CircuitBreaker.of(name, CircuitBreakerConfig.custom()
                .slidingWindowSize(10)
                .minimumNumberOfCalls(5)
                .failureRateThreshold(50)
                .waitDurationInOpenState(Duration.ofMillis(300))
                .permittedNumberOfCallsInHalfOpenState(2)
                // false (the default): OPEN → HALF_OPEN only when the next call arrives. true: a timer does it.
                .automaticTransitionFromOpenToHalfOpenEnabled(automaticHalfOpen)
                .build());
    }

    public static Retry retry(String name) {
        return Retry.of(name, RetryConfig.custom()
                .maxAttempts(3)
                // 100 ms, 200 ms… each randomised ±50%, so clients that failed together don't retry together
                .intervalFunction(IntervalFunction.ofExponentialRandomBackoff(Duration.ofMillis(100), 2.0, 0.5))
                .retryExceptions(ResourceAccessException.class)       // timeouts and connection errors
                .ignoreExceptions(CallNotPermittedException.class)    // the breaker is open: retrying is pointless
                .build());
    }
}
