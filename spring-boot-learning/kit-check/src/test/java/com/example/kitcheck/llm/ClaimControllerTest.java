package com.example.kitcheck.llm;

import com.example.kitcheck.llm.ClaimExtractor.Extraction;
import com.example.kitcheck.web.ApiExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** The endpoint around the extractor: a refusal or an unusable answer is a 422 for a human, never a guess. */
@WebMvcTest(ClaimController.class)
@Import(ApiExceptionHandler.class)
class ClaimControllerTest {

    @Autowired MockMvc mvc;
    @MockitoBean ClaimExtractor extractor;

    static final com.anthropic.models.messages.Usage USAGE = LlmSupportTest.usage(600, 150, 0, 0);

    @Test
    void anExtractionIs200() throws Exception {
        when(extractor.extract(anyString())).thenReturn(new Extraction.Extracted(new Fnol("Dana Okafor", "POL-20481",
                "2026-03-14", Fnol.LossType.BAGGAGE_LOST, "1250.00", "GBP", List.of()), USAGE));

        mvc.perform(post("/api/v1/claims/extract").contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"lost bag\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lossType").value("BAGGAGE_LOST"));
    }

    @Test
    void aRefusalIs422ProblemDetail() throws Exception {
        when(extractor.extract(anyString())).thenReturn(new Extraction.Refused("cyber", USAGE));

        mvc.perform(post("/api/v1/claims/extract").contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"lost bag\"}"))
                .andExpect(status().isUnprocessableContent())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.detail").value(containsString("claims handler")));
    }

    @Test
    void anUnreachableModelIs503WithRetryAfter() throws Exception {
        when(extractor.extract(anyString())).thenThrow(new com.anthropic.errors.AnthropicIoException("timed out after retries"));

        mvc.perform(post("/api/v1/claims/extract").contentType(MediaType.APPLICATION_JSON).content("{\"email\":\"lost bag\"}"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(header().string("Retry-After", "30"));
    }

    @Test
    void blankInputNeverReachesTheModel() throws Exception {
        mvc.perform(post("/api/v1/claims/extract").contentType(MediaType.APPLICATION_JSON).content("{\"email\":\" \"}"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(extractor);   // no tokens spent on input we'd reject anyway
    }
}
