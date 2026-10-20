package com.example.kitcheck.catalog;

import com.example.kitcheck.web.ApiExceptionHandler;
import com.example.kitcheck.web.RequestIdFilter;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Web slice: only the MVC layer starts; the service is a Mockito mock (@MockitoBean: @MockBean is gone in Boot 4). */
@WebMvcTest(AuthorController.class)
@Import({ApiExceptionHandler.class, RequestIdFilter.class})
class AuthorControllerTest {

    @Autowired MockMvc mvc;
    @MockitoBean AuthorService service;

    @Test
    void validRequestIs201() throws Exception {
        when(service.create(any())).thenReturn(new AuthorSummary(1L, "Ada", List.of("Notes")));

        mvc.perform(post("/api/v1/authors").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Ada","titles":["Notes"]}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Ada"))
                .andExpect(header().exists(RequestIdFilter.HEADER));
    }

    @Test
    void blankNameIs400WithTheFieldNamed() throws Exception {
        mvc.perform(post("/api/v1/authors").contentType(MediaType.APPLICATION_JSON).content("""
                        {"name":" "}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.fields.name").exists());
        verifyNoInteractions(service);   // rejected before the service
    }

    @Test
    void aSafeIncomingRequestIdIsKeptAndAnUnsafeOneReplaced() throws Exception {
        when(service.create(any())).thenReturn(new AuthorSummary(1L, "Ada", List.of()));
        mvc.perform(post("/api/v1/authors").header(RequestIdFilter.HEADER, "abc-123")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Ada\"}"))
                .andExpect(header().string(RequestIdFilter.HEADER, "abc-123"));
        mvc.perform(post("/api/v1/authors").header(RequestIdFilter.HEADER, "<script>")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"Ada\"}"))
                .andExpect(header().string(RequestIdFilter.HEADER, org.hamcrest.Matchers.not("<script>")));
    }
}
