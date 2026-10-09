---
title: REST API Reference
description: Complete endpoint specification for iPXE ZTP APIs and boot handlers.
---

The **iPXE ZTP** backend exposes JSON REST APIs for the web console and automation scripts, alongside dynamic boot script handlers.

## Authentication

All `/api/*` endpoints (except login, health check, and the phone-home callback) require an authenticated session cookie obtained from `/api/auth/login`.

### 1. Authentication Endpoints

#### `POST /api/auth/login`
Authenticates an administrator.
- **Request Body**:
  ```json
  {
    "email": "admin@ipxe.local",
    "password": "admin@pwd"
  }
  ```
- **Response**: Sets `lab_v_ipxe_session` HTTP-only cookie and returns user details.

#### `POST /api/auth/logout`
Terminates the current session.

#### `GET /api/auth/me`
Returns the currently authenticated user profile.

---

## 2. Machine Management Endpoints

#### `GET /api/machines`
Returns a list of all registered machines.
- **Response**:
  ```json
  [
    {
      "id": 1,
      "mac": "52:54:00:12:34:56",
      "hostname": "node-01.lab.local",
      "status": "installed",
      "ip": "192.168.1.50",
      "os": "ubuntu-24.04.5",
      "storage_layout": "direct",
      "created_at": 1718000000,
      "updated_at": 1718000500
    }
  ]
  ```

#### `POST /api/machines`
Creates a new machine manually.

#### `GET /api/machines/:id`
Retrieves a specific machine by ID.

#### `PUT /api/machines/:id`
Updates machine attributes (hostname, IP, storage layout, OS release, SSH key).

#### `DELETE /api/machines/:id`
Removes a machine from the inventory.

#### `POST /api/machines/:id/approve`
Approves a `pending` machine, moving it to `approved`.

#### `POST /api/machines/:id/reinstall`
Resets an `installed` machine back to `approved` to trigger reinstallation on its next boot.

#### `POST /api/machines/:id/mark-installed`
Manually transitions a machine status to `installed` (useful if phone-home was network-restricted).

#### `POST /api/machines/installed`
Public callback endpoint invoked by cloud-init's `late-commands` upon OS installation completion.
- **Request Body**:
  ```json
  {
    "mac": "52:54:00:12:34:56"
  }
  ```

---

## 3. Settings & System Endpoints

#### `GET /api/settings`
Returns global server configuration (base URL, default OS images, default SSH keys, default APT mirror URL).

#### `PUT /api/settings`
Updates global server configuration (including `apt_mirror_default`).

#### `POST /api/settings/test-apt-mirror`
Probes target APT mirror URL for reachability and measures HTTP round-trip latency.
- **Request Body**:
  ```json
  {
    "url": "http://vn.archive.ubuntu.com/ubuntu/"
  }
  ```
- **Example Response**:
  ```json
  {
    "ok": true,
    "status_code": 200,
    "latency_ms": 483,
    "message": "Mirror reachable (483ms, HTTP 200)"
  }
  ```

#### `POST /api/assets/fetch`
Triggers downloading, caching, and ISO extraction for a specific OS release.

#### `GET /api/system/info`
Returns server runtime metrics:
```json
{
  "version": "0.1.0",
  "memory_used_mb": 42.5,
  "uptime_seconds": 86400,
  "dev_mode": false
}
```

#### `GET /healthz`
Returns `200 OK` health status for container orchestrators and startup readiness probes.

---

## 4. Boot & Provisioning Endpoints

#### `GET /boot.ipxe?mac=:mac`
Serves dynamically generated iPXE script tailored to the machine's current lifecycle state.

#### `GET /os/:os_name/:version/:mac/user-data`
Generates Ubuntu autoinstall cloud-init configuration containing partition layouts, network parameters, and `late-commands`.

#### `GET /assets/:os_name/:version/:file`
Serves cached OS boot files (`vmlinuz`, `initrd`).
