import http from 'k6/http';
import { sleep } from 'k6';
import { Counter } from 'k6/metrics';

function parseBool(value, fallback) {
  if (value === undefined || value === null || value === '') {
    return fallback;
  }
  const normalized = String(value).toLowerCase();
  if (normalized === 'true') {
    return true;
  }
  if (normalized === 'false') {
    return false;
  }
  return fallback;
}

function parsePositiveInt(value, fallback) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isFinite(parsed) && parsed > 0) {
    return parsed;
  }
  return fallback;
}

function parseFraction(value, fallback) {
  const parsed = Number.parseFloat(value);
  if (Number.isFinite(parsed) && parsed >= 0.0 && parsed <= 1.0) {
    return parsed;
  }
  return fallback;
}

function trimTrailingSlash(value) {
  return value.endsWith('/') ? value.slice(0, -1) : value;
}

const BASE_URL = trimTrailingSlash(__ENV.BASE_URL || 'http://127.0.0.1:8080');
const KEYSPACE = parsePositiveInt(__ENV.KEYSPACE, 20000);
const VALUE_BYTES = parsePositiveInt(__ENV.VALUE_BYTES, 256);
const REQUEST_TIMEOUT_MS = parsePositiveInt(__ENV.REQUEST_TIMEOUT_MS, 5000);
const REQUEST_TIMEOUT = `${REQUEST_TIMEOUT_MS}ms`;
const READ_RATIO = parseFraction(__ENV.READ_RATIO, 0.9);
const DISTRIBUTION = ((__ENV.DISTRIBUTION || 'uniform').toLowerCase() === 'sequential') ? 'sequential' : 'uniform';
const PRELOAD = parseBool(__ENV.PRELOAD, false);
const SKIP_MAIN = parseBool(__ENV.SKIP_MAIN, false);
const K6_VUS = parsePositiveInt(__ENV.K6_VUS, 32);
const K6_DURATION = __ENV.K6_DURATION || '120s';
const PRELOAD_RETRIES = parsePositiveInt(__ENV.PRELOAD_RETRIES, 3);
const PRELOAD_RETRY_SLEEP_MS = parsePositiveInt(__ENV.PRELOAD_RETRY_SLEEP_MS, 5);
const SETUP_TIMEOUT = __ENV.SETUP_TIMEOUT || '10m';
const SUMMARY_TREND_STATS = ['min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', 'max'];

const PAYLOAD = 'x'.repeat(VALUE_BYTES);

const preloadAttempt = new Counter('preload_attempt');
const preloadSuccess = new Counter('preload_success');
const preloadFailed = new Counter('preload_failed');
const readCount = new Counter('read_count');
const writeCount = new Counter('write_count');
const opSuccess = new Counter('op_success');
const opError = new Counter('op_error');
const readNotFound = new Counter('read_not_found');

let options;
if (SKIP_MAIN) {
  options = {
    discardResponseBodies: true,
    noConnectionReuse: false,
    setupTimeout: SETUP_TIMEOUT,
    summaryTrendStats: SUMMARY_TREND_STATS,
    scenarios: {
      main: {
        executor: 'shared-iterations',
        vus: Math.max(1, Math.min(K6_VUS, 4)),
        iterations: 1,
        maxDuration: K6_DURATION,
      },
    },
  };
} else {
  options = {
    discardResponseBodies: true,
    noConnectionReuse: false,
    setupTimeout: SETUP_TIMEOUT,
    summaryTrendStats: SUMMARY_TREND_STATS,
    scenarios: {
      main: {
        executor: 'constant-vus',
        vus: K6_VUS,
        duration: K6_DURATION,
      },
    },
  };
}

export { options };

function keyPath(index) {
  return `${BASE_URL}/v1/kv/key-${index}`;
}

function putRequest(url, payload) {
  return http.put(url, payload, {
    timeout: REQUEST_TIMEOUT,
    headers: {
      'Content-Type': 'application/octet-stream',
    },
  });
}

function getRequest(url) {
  return http.get(url, {
    timeout: REQUEST_TIMEOUT,
  });
}

let sequentialIndex = 0;

function nextKeyIndex() {
  if (DISTRIBUTION === 'sequential') {
    const idx = sequentialIndex % KEYSPACE;
    sequentialIndex += 1;
    return idx;
  }
  return Math.floor(Math.random() * KEYSPACE);
}

export function setup() {
  if (!PRELOAD) {
    return null;
  }

  for (let i = 0; i < KEYSPACE; i += 1) {
    const url = keyPath(i);
    preloadAttempt.add(1);

    let loaded = false;
    for (let attempt = 0; attempt < PRELOAD_RETRIES; attempt += 1) {
      const response = putRequest(url, PAYLOAD);
      if (response.status === 200) {
        preloadSuccess.add(1);
        loaded = true;
        break;
      }
      if (attempt < PRELOAD_RETRIES - 1) {
        sleep((PRELOAD_RETRY_SLEEP_MS * (attempt + 1)) / 1000.0);
      }
    }

    if (!loaded) {
      preloadFailed.add(1);
    }
  }

  return null;
}

export default function () {
  if (SKIP_MAIN) {
    sleep(0.05);
    return;
  }

  const keyIndex = nextKeyIndex();
  const url = keyPath(keyIndex);
  const read = Math.random() < READ_RATIO;

  if (read) {
    readCount.add(1);
    const response = getRequest(url);
    if (response.status === 200) {
      opSuccess.add(1);
      return;
    }
    if (response.status === 404) {
      opSuccess.add(1);
      readNotFound.add(1);
      return;
    }
    opError.add(1);
    return;
  }

  writeCount.add(1);
  const response = putRequest(url, PAYLOAD);
  if (response.status === 200) {
    opSuccess.add(1);
    return;
  }
  opError.add(1);
}
