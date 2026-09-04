---
title: "Launchpad — Apollo Airlines with Docker Compose"
description: "Build, run, inspect, break, and recover Apollo Airlines locally before moving it to Kubernetes."
---

# Launchpad: Docker Compose

**Goal:** Run Apollo Airlines locally, trace requests across containers, and
understand the application Kubernetes will manage in every later stage.

Launchpad contains the ten teaching workloads used throughout the course:
six application services, three PostgreSQL databases, and Redis. Compose can
also start Dozzle through an optional profile; it is a learning aid, not an
Apollo Airlines workload.

## Learner mission

By the end of this lab you will have:

1. built the six application images from their Dockerfiles;
2. started all ten workloads and inspected their shared Docker network;
3. logged in and followed an API request through multiple containers;
4. stopped a dependency and observed readiness fail;
5. restarted the dependency and proved recovery; and
6. inspected the non-root, read-only application containers; and
7. mapped Compose responsibilities to the Kubernetes objects introduced next.

## What you will use

| Concept | Where to inspect | Why it matters later |
|---|---|---|
| Dockerfile | `code/*/Dockerfile` | Defines the image executed by a Kubernetes Pod |
| Compose service | `docker-compose.yml` | Becomes a Deployment or StatefulSet |
| Environment variable | each service's `environment` block | Moves to ConfigMaps and Secrets |
| Service-name DNS | URLs such as `http://flight:8081` | Kubernetes Services provide stable naming |
| Health check | PostgreSQL and Redis `healthcheck` blocks | Kubernetes adds startup, liveness, and readiness probes |
| Named volume | `*-db-data` | Kubernetes replaces it with PVCs and StorageClasses |
| Shared network | `apollo-airlines` | Kubernetes provides a cluster network and DNS |
| Runtime user and filesystem | `USER` plus Compose hardening | Kubernetes later expresses these controls with `securityContext` |

## Prerequisites

From the repository root:

```bash
docker version
docker compose version
```

If either command fails, start Docker before continuing. The flagship command
example and verifier also use `curl` and `jq`. You do not need Go, Python,
Node.js, PostgreSQL, or Redis installed on the host; the images contain their
build tools and runtime dependencies.

Create a local secrets file before asking Compose to render the application:

```bash
cd stages/launchpad
cp .env.example .env
```

Change the example values in `.env`. Use URL-safe characters in the PostgreSQL
password because Compose embeds it in database URLs. `.env` is ignored by Git;
`.env.example` documents only the required variable names. These remain local
development credentials, not a production secret-management design.

## 1. Read the application shape

```text
Browser :3000
    │
    ├── identity :8080 ───────────────► identity-db :5432
    ├── flight :8081 ─────────────────► flight-db :5432
    ├── search :8083 ─────────────────► flight :8081
    └── booking :8082
          ├── identity :8080
          ├── flight :8081
          ├── booking-db :5432
          └── notification :8084 ─────► redis :6379
```

Open `docker-compose.yml` and find one example of each item in the table above.
Notice that containers call one another by Compose service name, not by
`localhost`.

## 2. Build and start Apollo Airlines

```bash
docker compose up --build --wait -d
docker compose ps
```

All ten workloads should report `healthy`; first-time image builds can take
several minutes. The optional Dozzle container is not part of this default
application lifecycle.

If a container exits or repeatedly restarts, inspect it before changing it:

```bash
docker compose ps --all
docker compose logs --tail=80 identity identity-db
```

## 3. Prove the system works

Open <http://localhost:3000>, or use the APIs directly:

```bash
curl -i http://localhost:8081/healthz
curl -i http://localhost:8081/readyz
curl -s http://localhost:8081/api/flights
curl -s http://localhost:8081/metrics | head
```

`/metrics` uses Prometheus text exposition. The values remain deliberately
minimal until Stage 6 adds real instrumentation and collection.

Log in with the seeded passenger account:

```bash
curl -s -X POST http://localhost:8080/api/users/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"passenger@apolloairlines.com","password":"pass123"}'
```

The response should contain a JWT. Use it to exercise the flagship workflow
across Booking, Identity, Flight, PostgreSQL, Notification, and Redis:

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/users/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"passenger@apolloairlines.com","password":"pass123"}' \
  | jq -r .token)

curl -s -X POST http://localhost:8082/api/bookings \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -H 'X-Request-ID: launchpad-booking-demo' \
  -d '{"flightId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"}' | jq
```

The booking should be `CONFIRMED`. The browser UI uses the same identity,
flight, booking, and search APIs.

## 4. Inspect, do not just observe green containers

```bash
# See the resolved Compose model.
docker compose config --services

# See the network and its attached containers.
docker network inspect launchpad_apollo-airlines

# Resolve a dependency by service name from inside a container.
docker compose exec booking getent hosts flight

# Follow structured logs while using the UI or APIs.
docker compose logs -f booking identity flight notification
```

Now inspect two security defaults without changing the running application:

```bash
# Each application image declares a non-root runtime user.
docker compose exec booking id
docker compose exec identity id
docker compose exec frontend id

# The application root filesystem is read-only. This prints the expected error.
docker compose exec booking sh -c \
  'touch /app/should-fail 2>/dev/null || echo "expected: /app is read-only"'
```

These defaults are used here rather than advertised as mastered. Stage 8 later
makes identity, filesystem, capability, and policy controls explicit and
attackable.

To use the optional Dozzle browser view at <http://localhost:8085>:

```bash
docker compose --profile tools up -d dozzle
```

Dozzle reads the Docker socket. Access to that socket is highly privileged even
when its bind mount is marked read-only, so the tool is excluded from the
default profile. The CLI remains the canonical log path.

## 5. Break readiness, then recover

The flight API depends on PostgreSQL. Stop that database deliberately:

```bash
docker compose stop flight-db
curl -i http://localhost:8081/healthz
curl -i http://localhost:8081/readyz
curl -i http://localhost:8083/readyz
curl -i http://localhost:8082/readyz
```

`flight /healthz` remains `200` because the process is alive. Flight readiness
becomes `503`; Search and Booking also become unready because their dependency
chain is no longer able to serve the flagship workflow. Inspect the evidence:

```bash
docker compose logs --tail=80 flight flight-db
```

Restore the dependency and watch recovery:

```bash
docker compose start flight-db
docker compose ps
curl -i --retry 15 --retry-delay 2 --retry-all-errors \
  http://localhost:8081/readyz
curl -i http://localhost:8083/readyz
curl -i http://localhost:8082/readyz
```

This distinction becomes Kubernetes liveness and readiness behavior in Stage 4.

## 6. Prove database persistence

Named Compose volumes survive container replacement:

```bash
docker compose exec identity-db \
  sh -c 'psql -U "$POSTGRES_USER" -d identity -c "SELECT count(*) FROM users;"'
docker compose stop identity-db
docker compose rm -f identity-db
docker compose up -d --wait identity-db
docker compose exec identity-db \
  sh -c 'psql -U "$POSTGRES_USER" -d identity -c "SELECT count(*) FROM users;"'
```

The count remains the same because the container is disposable but its named
volume is not. Stage 3 recreates this behavior with StatefulSets and PVCs.

## Clean up

Keep database data for the next Compose run:

```bash
docker compose down
```

Delete the containers **and** the three database volumes for a fresh start:

```bash
docker compose down --volumes
```

The second command intentionally removes local Launchpad data. It does not
delete images or affect Kubernetes clusters.

If you changed the PostgreSQL credentials after volumes had already been
initialized, use this fresh-start command. PostgreSQL applies initialization
credentials only when its data directory is empty.

## Maintainer verification

After the ten workloads are healthy, run the compact answer-key verifier:

```bash
./scripts/verify.sh
```

It checks the default/profile boundary, container health, non-root users,
read-only filesystems, privilege/capability controls, writable `/tmp` mounts,
health/readiness/metrics endpoints, and a reversible booking workflow. Passing
it does not replace the manual failure and persistence experiments above.

## Before Ignition

You should be able to answer:

1. Why does booking call `http://flight:8081` instead of `localhost:8081`?
2. What is the difference between a container image and a running container?
3. Why can `/healthz` succeed while `/readyz` fails?
4. Which data survives `docker compose down`, and what removes it?
5. Why is Dozzle excluded from the default profile even though its socket mount
   is marked read-only?
6. Which Compose features become Deployments, Services, ConfigMaps, Secrets,
   probes, and PVCs in Kubernetes?

Next, continue to [Ignition](../ignition/README.md), where the first container
runs as a Kubernetes Pod.
