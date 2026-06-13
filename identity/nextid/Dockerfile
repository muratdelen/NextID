ARG NEXTID_CORE_IMAGE_TAG=latest

FROM maven:3.9-eclipse-temurin-25 AS nextid_listener_build
WORKDIR /workspace
COPY identity/nextid/extensions/nextid-nextlog-listener/pom.xml .
COPY identity/nextid/extensions/nextid-nextlog-listener/src ./src
RUN mvn -q -DskipTests package

FROM ghcr.io/muratdelen/nextid-core:${NEXTID_CORE_IMAGE_TAG}
COPY --from=nextid_listener_build /workspace/target/nextid-nextlog-listener-0.1.0.jar /opt/keycloak/providers/nextid-nextlog-listener-0.1.0.jar
RUN /opt/keycloak/bin/kc.sh build
