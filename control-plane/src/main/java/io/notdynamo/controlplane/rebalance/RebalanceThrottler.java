package io.notdynamo.controlplane.rebalance;

public final class RebalanceThrottler {
    private final double pauseThresholdP99Ms;

    public RebalanceThrottler(double pauseThresholdP99Ms) {
        if (pauseThresholdP99Ms <= 0.0) {
            throw new IllegalArgumentException("pauseThresholdP99Ms must be > 0");
        }
        this.pauseThresholdP99Ms = pauseThresholdP99Ms;
    }

    public boolean allowMove(double currentReadP99Ms) {
        if (currentReadP99Ms < 0.0) {
            throw new IllegalArgumentException("currentReadP99Ms must be >= 0");
        }
        return currentReadP99Ms <= pauseThresholdP99Ms;
    }

    public double pauseThresholdP99Ms() {
        return pauseThresholdP99Ms;
    }
}
