package com.example.kitcheck.llm;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;

/**
 * One shared client: it holds a connection pool, so never build one per request.
 * The base URL is a setting so tests and the e2e stack can point it at a fake; the key only ever comes from the
 * environment (ANTHROPIC_API_KEY), never from a file in the repo.
 */
@Configuration
class ClaudeConfig {

    private static final Logger log = LoggerFactory.getLogger(ClaudeConfig.class);

    @Bean(destroyMethod = "close")
    AnthropicClient anthropicClient(@Value("${app.claude.base-url:}") String baseUrl,
                                    @Value("${ANTHROPIC_API_KEY:}") String apiKey,
                                    @Value("${app.claude.timeout:PT30S}") Duration timeout,
                                    @Value("${app.claude.max-retries:2}") int maxRetries) {
        if (apiKey.isBlank()) {
            log.warn("ANTHROPIC_API_KEY is not set: calls to Claude will fail with 401 until it is");
        }
        return client(baseUrl, apiKey.isBlank() ? "not-configured" : apiKey, timeout, maxRetries);
    }

    static AnthropicClient client(String baseUrl, String apiKey, Duration timeout, int maxRetries) {
        AnthropicOkHttpClient.Builder b = AnthropicOkHttpClient.builder()
                .apiKey(apiKey)
                .timeout(timeout)          // the whole request, retries are on top of it
                .maxRetries(maxRetries);   // the SDK retries 408/409/429/5xx and connection errors, with backoff
        if (!baseUrl.isBlank()) b.baseUrl(baseUrl);
        return b.build();
    }
}
