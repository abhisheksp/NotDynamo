package io.notdynamo.node.observability;

public record TelemetryContext(String traceId, String spanId, String correlationId) {
    public TelemetryContext {
        traceId = requireNonBlank(traceId, "traceId");
        spanId = requireNonBlank(spanId, "spanId");
        correlationId = requireNonBlank(correlationId, "correlationId");
    }

    private static String requireNonBlank(String value, String label) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(label + " must not be blank");
        }
        return value;
    }
}
