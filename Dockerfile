ARG NEXTID_BASE_VERSION=26.6.3

FROM quay.io/keycloak/keycloak:${NEXTID_BASE_VERSION} AS builder

USER root

COPY --chown=keycloak:root themes/nextid /opt/keycloak/themes/nextid
RUN chmod -R u=rwX,g=rX,o=rX /opt/keycloak/themes/nextid

USER keycloak

WORKDIR /opt/keycloak
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:${NEXTID_BASE_VERSION}

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]