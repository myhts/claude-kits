# syntax=docker/dockerfile:1
# Spring Boot image: build with the JDK, run on the JRE, as non-root, from layers ordered least → most often changed.
# Build from the folder that has pom.xml:  docker build -t <app>:<git-sha> .
# Replace <APP> with the Maven artifactId. Pin the image tags (here: Temurin 21) and bump them deliberately.

# ---- build stage: nothing from here reaches the runtime image except the extracted layers
FROM eclipse-temurin:21.0.8_9-jdk AS build
WORKDIR /src
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN --mount=type=cache,target=/root/.m2 ./mvnw -q -B dependency:go-offline
COPY src src
RUN --mount=type=cache,target=/root/.m2 ./mvnw -q -B package -DskipTests \
 && java -Djarmode=tools -jar target/<APP>-*.jar extract --layers --launcher --destination /layers

# ---- runtime stage
FROM eclipse-temurin:21.0.8_9-jre
RUN groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid app --no-create-home app
WORKDIR /app
COPY --from=build /layers/dependencies/ ./
COPY --from=build /layers/spring-boot-loader/ ./
COPY --from=build /layers/snapshot-dependencies/ ./
COPY --from=build /layers/application/ ./
# Heap from the container's memory limit, never a fixed -Xmx. G1 explicitly: under 2 CPUs or ~1.8 GiB the JVM
# silently picks SerialGC. Exit on OOM so the orchestrator restarts a clean process.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError"
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
