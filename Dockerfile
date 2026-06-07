ARG NEXTID_BASE_VERSION=26.6.3
ARG NEXTID_CORE_IMAGE=ghcr.io/muratdelen/nextid-core

FROM ${NEXTID_CORE_IMAGE}:${NEXTID_BASE_VERSION} AS builder

USER root

# NextId theme
COPY --chown=keycloak:root themes/nextid /opt/keycloak/themes/nextid

# Custom providers
COPY --chown=keycloak:root providers /opt/keycloak/providers

# NextId realm config and helper scripts
COPY --chown=keycloak:root realm-config /opt/nextid/realm-config

RUN chmod -R u=rwX,g=rX,o=rX /opt/keycloak/themes/nextid \
    && chmod -R u=rwX,g=rX,o=rX /opt/keycloak/providers \
    && chmod -R u=rwX,g=rX,o=rX /opt/nextid

USER keycloak

WORKDIR /opt/keycloak

RUN /opt/keycloak/bin/kc.sh build

FROM ${NEXTID_CORE_IMAGE}:${NEXTID_BASE_VERSION}

USER root

COPY --from=builder /opt/keycloak/ /opt/keycloak/
COPY --from=builder /opt/nextid/ /opt/nextid/

RUN chmod -R u=rwX,g=rX,o=rX /opt/keycloak \
    && chmod -R u=rwX,g=rX,o=rX /opt/nextid

USER keycloak

WORKDIR /opt/keycloak

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]