package io.notdynamo.node.observability;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class TelemetryPropagationTest {
    @Test
    void propagatesTelemetryHeadersAcrossBoundaries() {
        TelemetryContext context = new TelemetryContext("trace-123", "span-456", "corr-789");
        TelemetryPropagator propagator = new TelemetryPropagator();

        Map<String, String> headers = new HashMap<>();
        propagator.inject(context, headers);

        TelemetryContext extracted = propagator.extract(headers).orElseThrow();
        assertEquals(context.traceId(), extracted.traceId());
        assertEquals(context.spanId(), extracted.spanId());
        assertEquals(context.correlationId(), extracted.correlationId());
        assertTrue(headers.containsKey(TelemetryPropagator.TRACE_ID_HEADER));
    }
}
