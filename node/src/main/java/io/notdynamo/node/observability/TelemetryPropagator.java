package io.notdynamo.node.observability;

import java.util.Map;
import java.util.Objects;
import java.util.Optional;

public final class TelemetryPropagator {
    public static final String TRACE_ID_HEADER = "x-trace-id";
    public static final String SPAN_ID_HEADER = "x-span-id";
    public static final String CORRELATION_ID_HEADER = "x-correlation-id";

    public void inject(TelemetryContext context, Map<String, String> headers) {
        Objects.requireNonNull(context, "context must not be null");
        Objects.requireNonNull(headers, "headers must not be null");

        headers.put(TRACE_ID_HEADER, context.traceId());
        headers.put(SPAN_ID_HEADER, context.spanId());
        headers.put(CORRELATION_ID_HEADER, context.correlationId());
    }

    public Optional<TelemetryContext> extract(Map<String, String> headers) {
        Objects.requireNonNull(headers, "headers must not be null");

        String traceId = headers.get(TRACE_ID_HEADER);
        String spanId = headers.get(SPAN_ID_HEADER);
        String correlationId = headers.get(CORRELATION_ID_HEADER);

        if (isBlank(traceId) || isBlank(spanId) || isBlank(correlationId)) {
            return Optional.empty();
        }

        return Optional.of(new TelemetryContext(traceId, spanId, correlationId));
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
