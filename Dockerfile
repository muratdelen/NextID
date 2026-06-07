ARG KEYCLOAK_VERSION=26.6.3

FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION} AS builder

COPY themes/nextid /opt/keycloak/themes/nextid

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:${KEYCLOAK_VERSION}

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
