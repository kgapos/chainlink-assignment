import http from "k6/http";
import { check, sleep } from "k6";

http.setResponseCallback(http.expectedStatuses({ min: 200, max: 499 }));

const baseUrl = __ENV.BASE_URL || "http://envoy:80";
const testProfile = __ENV.TEST_PROFILE || "smoke";
const requestProfile = JSON.parse(open("./requests.json"));

const smokeVus = Number(__ENV.SMOKE_VUS || 3);
const smokeDuration = __ENV.SMOKE_DURATION || "1m";
const loadMaxVus = Number(__ENV.LOAD_MAX_VUS || 30);

const smokeScenario = {
  executor: "constant-vus",
  vus: smokeVus,
  duration: smokeDuration,
  exec: "smoke",
  tags: { scenario: "smoke" }
};

const loadScenario = {
  executor: "ramping-vus",
  startVUs: 0,
  stages: [
    { duration: "2m", target: Math.max(1, Math.floor(loadMaxVus / 3)) },
    { duration: "3m", target: loadMaxVus },
    { duration: "2m", target: loadMaxVus },
    { duration: "1m", target: 0 }
  ],
  gracefulRampDown: "30s",
  exec: "load",
  tags: { scenario: "load" }
};

export const options = {
  discardResponseBodies: true,
  thresholds: {
    http_req_failed: ["rate<0.02"],
    http_req_duration: ["p(95)<1500"]
  },
  scenarios: testProfile === "load" ? { load: loadScenario } : { smoke: smokeScenario }
};

const endpoints = requestProfile.endpoints || [];
const totalWeight = endpoints.reduce((acc, endpoint) => acc + (endpoint.weight || 0), 0);

function pickEndpoint() {
  if (!endpoints.length || totalWeight <= 0) {
    return {
      method: "GET",
      template: "/blocks/best",
      samples: [{ uri: "/blocks/best", body: "" }]
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
      tags: { endpoint: endpoint.template, method: "POST" }
    });
  } else {
    res = http.get(url, {
      tags: { endpoint: endpoint.template, method: "GET" }
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
