# ---------- Stage 1: Build with Maven ----------
FROM maven:3.9-eclipse-temurin-11-alpine AS builder

WORKDIR /app

# 1) Cache deps — copy only pom.xml first
COPY pom.xml .
RUN mvn -B -DskipTests dependency:go-offline

# 2) Copy sources and build
COPY src ./src
# If you have extra build files (e.g., resources outside src), copy them here.

RUN mvn -B -DskipTests package

# ---------- Stage 2: Runtime ----------
FROM amazoncorretto:11-alpine-jdk

WORKDIR /app
# Copy the built JAR from builder
COPY --from=builder /app/target/*.jar /app/app.jar

# Non-root runtime user (good practice)
RUN addgroup -S app && adduser -S app -G app
USER app

EXPOSE 8081
ENV JAVA_OPTS=""

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
