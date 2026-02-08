import http from "k6/http";
import { check, sleep } from "k6";

http.setResponseCallback(http.expectedStatuses({ min: 200, max: 499 }));

const baseUrl = __ENV.BASE_URL || "http://envoy:80";
const testProfile = __ENV.TEST_PROFILE || "smoke";
const requestProfile = JSON.parse(open("./requests.json"));

const maxVUs = Number(__ENV.MAX_VUS || 1000);
const stageDuration = __ENV.STAGE_DURATION || "30s";

// Smoke scenario: run a constant number of VUs for a short duration
const smokeScenario = {
  executor: "constant-vus",
  vus: "10",
  duration: "10s",
  exec: "smoke",
  tags: { scenario: "smoke" },
};

// Load scenario: ramp up to a maximum number of VUs over a period of time
const loadScenario = {
  executor: "ramping-vus",
  startVUs: 0,
  stages: [
    {
      duration: stageDuration,
      target: Math.max(1, Math.floor(maxVUs / 10)), // 10% of maxVUs
    },
    {
      duration: stageDuration,
      target: Math.max(1, Math.floor(maxVUs / 4)), // 25% of maxVUs
    },
    { duration: stageDuration, target: maxVUs }, // 100% of maxVUs
    { duration: stageDuration, target: 0 },
  ],
  gracefulRampDown: stageDuration,
  exec: "load",
  tags: { scenario: "load" },
};

export const options = {
  discardResponseBodies: true,
  thresholds: {
    http_req_failed: ["rate<0.02"],
    http_req_duration: ["p(95)<1500"],
  },
  scenarios:
    testProfile === "load" ? { load: loadScenario } : { smoke: smokeScenario },
};

const endpoints = requestProfile.endpoints || [];
const totalWeight = endpoints.reduce(
  (acc, endpoint) => acc + (endpoint.weight || 0),
  0,
);

function pickEndpoint() {
  if (!endpoints.length || totalWeight <= 0) {
    return {
      method: "GET",
      template: "/blocks/best",
      samples: [{ uri: "/blocks/best", body: "" }],
    };
  }

  let cursor = Math.random() * totalWeight;
  for (const endpoint of endpoints) {
    cursor -= endpoint.weight;
    if (cursor <= 0) {
      return endpoint;
    }
  }

  return endpoints[endpoints.length - 1];
}

function pickSample(endpoint) {
  if (!endpoint.samples || !endpoint.samples.length) {
    return { uri: "/blocks/best", body: "" };
  }
  return endpoint.samples[Math.floor(Math.random() * endpoint.samples.length)];
}

function executeRequest() {
  const endpoint = pickEndpoint();
  const sample = pickSample(endpoint);
  const url = `${baseUrl}${sample.uri}`;

  let res;
  if (endpoint.method === "POST") {
    res = http.post(url, sample.body || "{}", {
      headers: { "Content-Type": "application/json" },
      tags: { endpoint: endpoint.template, method: "POST" },
    });
  } else {
    res = http.get(url, {
      tags: { endpoint: endpoint.template, method: "GET" },
    });
  }

  check(res, { "status < 500": (r) => r.status < 500 });
}

export function smoke() {
  executeRequest();
  sleep(1);
}

export function load() {
  executeRequest();
  sleep(Math.random() * 0.7 + 0.1);
}
