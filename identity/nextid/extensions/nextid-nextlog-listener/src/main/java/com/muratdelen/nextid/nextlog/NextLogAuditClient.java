package com.muratdelen.nextid.nextlog;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class NextLogAuditClient {

    private static final String DEFAULT_NEXTLOG_URL = "http://nextlog-core:8095/api/audit-events";
    private static final String API_KEY_HEADER = "X-NextLog-Api-Key";

    public void send(String payload) {
        HttpURLConnection connection = null;

        try {
            URL url = new URL(nextLogUrl());
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Content-Type", "application/json");

            String apiKey = apiKey();
            if (hasText(apiKey)) {
                connection.setRequestProperty(API_KEY_HEADER, apiKey);
            }

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

    private String apiKey() {
        return System.getenv("NEXTLOG_INGEST_API_KEY");
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
