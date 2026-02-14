package io.notdynamo.controlplane;

public record PartitionMapVersion(long epoch) {
    public PartitionMapVersion {
        if (epoch < 0) {
            throw new IllegalArgumentException("epoch must be non-negative");
        }
    }

    public PartitionMapVersion next() {
        return new PartitionMapVersion(epoch + 1);
    }
}
