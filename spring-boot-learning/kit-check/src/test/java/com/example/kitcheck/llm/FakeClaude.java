package com.example.kitcheck.llm;

import com.anthropic.client.AnthropicClient;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Executors;
import java.util.function.Function;

/**
 * A local stand-in for POST /v1/messages: replies with queued (or computed) responses and keeps every request body,
 * so tests check both what the app sends and how it handles what comes back, without a key and without cost.
 * The response bodies are written in the documented shape; they are not recordings of the live API.
 */
final class FakeClaude implements AutoCloseable {

    record Reply(int status, String body, long delayMs) { }

    static final ObjectMapper JSON = new ObjectMapper();

    private final HttpServer server;
    private final Deque<Reply> queue = new ArrayDeque<>();
    final List<String> requests = new CopyOnWriteArrayList<>();
    private volatile Function<JsonNode, Reply> responder;

    FakeClaude() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/messages", ex -> {
            String body = new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            requests.add(body);
            Reply r;
            synchronized (queue) { r = queue.poll(); }
            if (r == null && responder != null) r = responder.apply(JSON.readTree(body));
            if (r == null) r = new Reply(500, "{\"type\":\"error\",\"error\":{\"type\":\"api_error\",\"message\":\"no reply queued\"}}", 0);
            if (r.delayMs() > 0) {
                try { Thread.sleep(r.delayMs()); } catch (InterruptedException ignored) { }
            }
            byte[] bytes = r.body().getBytes(StandardCharsets.UTF_8);
            ex.getResponseHeaders().add("content-type", "application/json");
            ex.sendResponseHeaders(r.status(), bytes.length);
            ex.getResponseBody().write(bytes);
            ex.close();
        });
        server.setExecutor(Executors.newCachedThreadPool());
        server.start();
    }

    FakeClaude reply(int status, String body) { return reply(status, body, 0); }

    FakeClaude reply(int status, String body, long delayMs) {
        synchronized (queue) { queue.add(new Reply(status, body, delayMs)); }
        return this;
    }

    FakeClaude respondWith(Function<JsonNode, Reply> responder) {
        this.responder = responder;
        return this;
    }

    String baseUrl() { return "http://127.0.0.1:" + server.getAddress().getPort(); }

    AnthropicClient client(Duration timeout, int maxRetries) {
        return ClaudeConfig.client(baseUrl(), "test-key", timeout, maxRetries);
    }

    JsonNode request(int i) {
        try { return JSON.readTree(requests.get(i)); } catch (IOException e) { throw new UncheckedIOException(e); }
    }

    /** A Messages API response with one text block (the shape documented for POST /v1/messages). */
    static String message(String text, String stopReason, long in, long out, long cacheWrite, long cacheRead) {
        try {
            return """
                    {"id":"msg_fake","type":"message","role":"assistant","model":"claude-haiku-5-5",
                     "content":[{"type":"text","text":%s}],
                     "stop_reason":"%s","stop_sequence":null,
                     "usage":{"input_tokens":%d,"output_tokens":%d,"cache_creation_input_tokens":%d,"cache_read_input_tokens":%d}}
                    """.formatted(JSON.writeValueAsString(text), stopReason, in, out, cacheWrite, cacheRead);
        } catch (IOException e) { throw new UncheckedIOException(e); }
    }

    static String resource(String path) {
        try { return Files.readString(Path.of("src/test/resources", path)); } catch (IOException e) { throw new UncheckedIOException(e); }
    }

    @Override
    public void close() { server.stop(0); }
}
