package com.muratdelen.nextid.nextlog;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class NextLogAuditClient {

    private static final String DEFAULT_NEXTLOG_URL = "http://next-log-service:8092/api/audit-events";

    public void send(String payload) {
        HttpURLConnection connection = null;
        try {
            URL url = new URL(nextLogUrl());
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Content-Type", "application/json");
            connection.setDoOutput(true);

            byte[] bytes = payload.getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = connection.getOutputStream()) {
                os.write(bytes);
            }

            connection.getResponseCode();
        } catch (Exception e) {
            System.err.println("NextID audit send failed: " + e.getMessage());
        } finally {
            if (connection != null) {
                connection.disconnect();
            }
        }
    }

    private String nextLogUrl() {
        String value = System.getenv("NEXTLOG_AUDIT_URL");
        return hasText(value) ? value : DEFAULT_NEXTLOG_URL;
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
