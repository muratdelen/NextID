package com.muratdelen.nextid.nextlog;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class NextLogAuditClient {

    private static final String DEFAULT_NEXTLOG_URL = "http://nextlog-core:8095/api/audit-events";
    private static final String API_KEY_HEADER = "X-NextLog-Api-Key";
    private static final int CONNECT_TIMEOUT_MILLIS = 2_000;
    private static final int READ_TIMEOUT_MILLIS = 3_000;

    public void send(String payload) {
        HttpURLConnection connection = null;

        try {
            URL url = new URL(nextLogUrl());
            connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Content-Type", "application/json");
            connection.setConnectTimeout(CONNECT_TIMEOUT_MILLIS);
            connection.setReadTimeout(READ_TIMEOUT_MILLIS);

            String apiKey = apiKey();
            if (hasText(apiKey)) {
                connection.setRequestProperty(API_KEY_HEADER, apiKey);
            }

            connection.setDoOutput(true);

            byte[] bytes = payload.getBytes(StandardCharsets.UTF_8);
            try (OutputStream os = connection.getOutputStream()) {
                os.write(bytes);
            }

            int responseCode = connection.getResponseCode();
            if (responseCode < 200 || responseCode >= 300) {
                System.err.println("NextID audit send failed: NextLog returned HTTP " + responseCode);
            }
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
