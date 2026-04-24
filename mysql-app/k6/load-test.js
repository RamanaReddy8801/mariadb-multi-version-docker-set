import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m',  target: 100  },
        { duration: '5m',  target: 500  },
        { duration: '10m', target: 1000 },
        { duration: '5m',  target: 500  },
        { duration: '3m',  target: 0    },
      ],
      exec: 'testAll',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<10000'],
    http_req_failed:   ['rate<0.1'],
  },
};

const APPS = [
  __ENV.MYSQL_APP_10_URL || 'http://mysql-app-10:4000',
  __ENV.MYSQL_APP_11_URL || 'http://mysql-app-11:4000',
  __ENV.MYSQL_APP_12_URL || 'http://mysql-app-12:4000',
];

const ENDPOINTS = [
  { path: '/hr/employees/search',            method: 'GET'  },
  { path: '/admin/employees/search',         method: 'GET'  },
  { path: '/admin/departments/details',      method: 'GET'  },
  { path: '/admin/employees/details',        method: 'GET'  },
  { path: '/admin/reports/salary_audit',     method: 'GET'  },
  { path: '/admin/reports/transfer_audit',   method: 'GET'  },
  { path: '/admin/employees/data_export',    method: 'GET'  },
  { path: '/admin/employees/bulk_title_update', method: 'PUT' },
];

export function testAll() {
  const app      = APPS[Math.floor(Math.random() * APPS.length)];
  const endpoint = ENDPOINTS[Math.floor(Math.random() * ENDPOINTS.length)];

  const params = { headers: { 'Content-Type': 'application/json' }, timeout: '15s' };

  let res;
  if (endpoint.method === 'PUT') {
    res = http.put(`${app}${endpoint.path}`, null, params);
  } else {
    res = http.get(`${app}${endpoint.path}`, params);
  }

  check(res, { 'status 200': (r) => r.status === 200 });

  sleep(Math.random() * 2 + 1);
}
