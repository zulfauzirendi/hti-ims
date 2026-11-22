import http from 'k6/http';
import { check, sleep } from 'k6';

// Load Test Blueprint (SRS-QAL-001 & SRS-QAL-002)
// Jalankan: k6 run -e BASE_URL=https://localhost -e TOKEN=<jwt> backend/tests/load/k6_search_mutation.js
export const options = {
  vus: 50,
  duration: '3m',
  thresholds: {
    'http_req_duration{endpoint:search}': ['p(95)<300', 'p(99)<500'],
    'http_req_duration{endpoint:dashboard}': ['p(95)<500'],
    http_req_failed: ['rate<0.001'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://127.0.0.1:3000';
const TOKEN = __ENV.TOKEN || '';
const QUERIES = ['crane', 'grinding', 'helm', 'harness', 'kunci', 'welding', 'chain block', 'caliper'];

export default function () {
  const headers = { Authorization: `Bearer ${TOKEN}` };
  const q = QUERIES[Math.floor(Math.random() * QUERIES.length)];

  const searchRes = http.get(`${BASE_URL}/api/v1/items/search?q=${encodeURIComponent(q)}&page=1&limit=20`, {
    headers,
    tags: { endpoint: 'search' },
  });
  check(searchRes, { 'search 200': (r) => r.status === 200 });

  const dashRes = http.get(`${BASE_URL}/api/v1/dashboard/summary`, {
    headers,
    tags: { endpoint: 'dashboard' },
  });
  check(dashRes, { 'dashboard 200': (r) => r.status === 200 });

  sleep(0.5);
}
