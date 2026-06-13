package com.muratdelen.nextid.nextlog;

import org.keycloak.events.Event;
import org.keycloak.events.EventListenerProvider;
import org.keycloak.events.EventType;
import org.keycloak.events.admin.AdminEvent;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;
import java.util.Map;
import java.util.Set;

public class NextIdEventListenerProvider implements EventListenerProvider {

    private static final String DEFAULT_NEXTLOG_URL = "http://nextlog-core:8095/api/audit-events";
    private static final String DEFAULT_MODULE = "nextid";

    private static final Set<EventType> ALLOWED_USER_EVENTS = Set.of(
            EventType.LOGIN,
            EventType.LOGIN_ERROR,
            EventType.LOGOUT,
            EventType.LOGOUT_ERROR,
            EventType.REGISTER,
            EventType.REGISTER_ERROR,
            EventType.UPDATE_PROFILE,
            EventType.UPDATE_PROFILE_ERROR,
            EventType.UPDATE_PASSWORD,
            EventType.UPDATE_PASSWORD_ERROR,
            EventType.UPDATE_EMAIL,
            EventType.UPDATE_EMAIL_ERROR,
            EventType.VERIFY_EMAIL,
            EventType.VERIFY_EMAIL_ERROR,
            EventType.CLIENT_LOGIN,
            EventType.CLIENT_LOGIN_ERROR
    );

    private final HttpClient httpClient = HttpClient.newHttpClient();

    @Override
    public void onEvent(Event event) {
        if (event.getType() == null || !ALLOWED_USER_EVENTS.contains(event.getType())) {
            return;
        }

        String action = event.getType().name();
        String status = action.endsWith("_ERROR") ? "FAILED" : "SUCCESS";

        String json = """
                {
                  "traceId": "%s",
                  "module": "%s",
                  "action": "%s",
                  "actorUserId": "%s",
                  "targetUserId": "%s",
                  "status": "%s",
                  "ipAddress": "%s",
                  "message": "%s",
                  "metadata": "%s"
                }
                """.formatted(
                escape(valueOrFallback(event.getId(), "event-" + event.getTime())),
                escape(module()),
                escape(action),
                escape(event.getUserId()),
                escape(event.getUserId()),
                escape(status),
                escape(event.getIpAddress()),
                escape("NextID user event: " + action),
                escape(metadataFromUserEvent(event))
        );

        send(json);
    }

    @Override
    public void onEvent(AdminEvent event, boolean includeRepresentation) {
        String operation = event.getOperationType() != null ? event.getOperationType().name() : "UNKNOWN_OPERATION";
        String resource = event.getResourceTypeAsString() != null ? event.getResourceTypeAsString() : "UNKNOWN_RESOURCE";
        String action = "ADMIN_" + operation + "_" + resource;

        String actorUserId = null;
        String ipAddress = null;

        if (event.getAuthDetails() != null) {
            actorUserId = event.getAuthDetails().getUserId();
            ipAddress = event.getAuthDetails().getIpAddress();
        }

        String json = """
                {
                  "traceId": "%s",
                  "module": "%s",
                  "action": "%s",
                  "actorUserId": "%s",
                  "targetUserId": "%s",
                  "status": "SUCCESS",
                  "ipAddress": "%s",
                  "message": "%s",
                  "metadata": "%s"
                }
                """.formatted(
                escape("admin-" + event.getTime()),
                escape(module()),
                escape(action),
                escape(actorUserId),
                escape(event.getResourcePath()),
                escape(ipAddress),
                escape("NextID admin event: " + action),
                escape(metadataFromAdminEvent(event))
        );

        send(json);
    }

    private void send(String json) {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(nextLogUrl()))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json))
                    .build();

            httpClient.send(request, HttpResponse.BodyHandlers.discarding());
        } catch (IOException | InterruptedException e) {
            System.err.println("NextID audit send failed: " + e.getMessage());
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
        } catch (Exception e) {
            System.err.println("NextID audit unexpected error: " + e.getMessage());
        }
    }

    private String nextLogUrl() {
        String value = System.getenv("NEXTLOG_AUDIT_URL");
        return hasText(value) ? value : DEFAULT_NEXTLOG_URL;
    }

    private String module() {
        String value = System.getenv("NEXTLOG_MODULE");
        return hasText(value) ? value : DEFAULT_MODULE;
    }

    private String metadataFromUserEvent(Event event) {
        StringBuilder sb = new StringBuilder();
        sb.append("{");
        append(sb, "realmId", event.getRealmId());
        append(sb, "clientId", event.getClientId());
        append(sb, "sessionId", event.getSessionId());

        Map<String, String> details = event.getDetails();
        if (details != null) {
            append(sb, "username", details.get("username"));
            append(sb, "auth_method", details.get("auth_method"));
            append(sb, "redirect_uri", details.get("redirect_uri"));
        }

        removeLastComma(sb);
        sb.append("}");
        return sb.toString();
    }

    private String metadataFromAdminEvent(AdminEvent event) {
        StringBuilder sb = new StringBuilder();
        sb.append("{");
        append(sb, "realmId", event.getRealmId());
        append(sb, "resourceType", event.getResourceTypeAsString());
        append(sb, "resourcePath", event.getResourcePath());
        append(sb, "operationType", event.getOperationType() != null ? event.getOperationType().name() : null);
        append(sb, "eventTime", Instant.ofEpochMilli(event.getTime()).toString());
        removeLastComma(sb);
        sb.append("}");
        return sb.toString();
    }

    private void append(StringBuilder sb, String key, String value) {
        if (!hasText(value)) {
            return;
        }

        sb.append("\"")
                .append(escape(key))
                .append("\":\"")
                .append(escape(value))
                .append("\",");
    }

    private void removeLastComma(StringBuilder sb) {
        if (sb.length() > 1 && sb.charAt(sb.length() - 1) == ',') {
            sb.deleteCharAt(sb.length() - 1);
        }
    }

    private String valueOrFallback(String value, String fallback) {
        return hasText(value) ? value : fallback;
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private String escape(String value) {
        if (value == null) {
            return "";
        }

        return value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r");
    }

    @Override
    public void close() {
    }
}
