package com.example.kitcheck.catalog;

import com.example.kitcheck.support.PostgresTestcontainer;
import com.example.kitcheck.web.RequestIdFilter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.client.RestTestClient;

import static org.assertj.core.api.Assertions.assertThat;

/** The whole app on a real port, a real Postgres, and the real JSON log output. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "logging.level.com.example.kitcheck=DEBUG")
@AutoConfigureRestTestClient
@Import(PostgresTestcontainer.class)
@ExtendWith(OutputCaptureExtension.class)
class AuthorApiIT {

    @Autowired RestTestClient client;

    @Test
    void createThenListOverHttp(CapturedOutput output) {
        client.post().uri("/api/v1/authors").contentType(MediaType.APPLICATION_JSON)
                .header(RequestIdFilter.HEADER, "it-req-1")
                .body("{\"name\":\"Ada\",\"titles\":[\"Notes\"]}")
                .exchange()
                .expectStatus().isCreated()
                .expectBody().jsonPath("$.titles[0]").isEqualTo("Notes");

        client.get().uri("/api/v1/authors").exchange()
                .expectStatus().isOk()
                .expectBody().jsonPath("$[0].name").isEqualTo("Ada");

        // structured logging (ecs) writes JSON lines, and MDC values become fields of every line in the request
        assertThat(output.getOut()).contains("\"requestId\":\"it-req-1\"");
    }
}
