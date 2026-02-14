package io.notdynamo.controlplane.lease;

public record LeaseRecord(String holderIdentity, long renewTimeMillis, long leaseDurationMillis, long version) {
    public LeaseRecord {
        if (holderIdentity == null || holderIdentity.isBlank()) {
            throw new IllegalArgumentException("holderIdentity must not be blank");
        }
        if (renewTimeMillis < 0) {
            throw new IllegalArgumentException("renewTimeMillis must be >= 0");
        }
        if (leaseDurationMillis <= 0) {
            throw new IllegalArgumentException("leaseDurationMillis must be > 0");
        }
        if (version < 0) {
            throw new IllegalArgumentException("version must be >= 0");
        }
    }

    public long expiresAtMillis() {
        return renewTimeMillis + leaseDurationMillis;
    }

    public boolean isExpiredAt(long nowMillis) {
        return nowMillis > expiresAtMillis();
    }
}
