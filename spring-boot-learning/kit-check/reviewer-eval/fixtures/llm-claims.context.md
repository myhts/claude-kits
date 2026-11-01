## This project

- What it is: **claims-triage**, a small service that reads a travel insurance claim email, asks Claude
  (`claude-haiku-5-5`, official Java SDK) to recommend a decision, and shows adjusters a summary page.
- Intended behaviour: the model **recommends** (approve, need more information, refer to an adjuster) and
  summarises; **adjusters decide**. Claim emails come from members of the public. Payments are made only for
  approved claims.
- Architecture: one Spring Boot module, controller → service; no database yet (results kept in memory).
- Java / Spring Boot version: Java 21, Spring Boot 4.1.1, anthropic-java 2.71.0.
- Build and run: `./mvnw spring-boot:run` · tests: none yet.
- Group id / base package: `com.example` / `com.example.claims`.
