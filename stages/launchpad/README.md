---
title: "Launchpad — Apollo Airlines with Docker Compose"
description: "Build, run, inspect, break, and recover Apollo Airlines locally before moving it to Kubernetes."
---

# Launchpad: Docker Compose

**Goal:** Run Apollo Airlines locally, trace requests across containers, and
understand the application Kubernetes will manage in every later stage.

Launchpad contains the ten teaching workloads used throughout the course:
six application services, three PostgreSQL databases, and Redis. Compose also
starts Dozzle as an optional log viewer; it is a learning aid, not an Apollo
Airlines workload.

## Learner mission

By the end of this lab you will have:

1. built the six application images from their Dockerfiles;
2. started all ten workloads and inspected their shared Docker network;
3. logged in and followed an API request through multiple containers;
4. stopped a dependency and observed readiness fail;
5. restarted the dependency and proved recovery; and
6. mapped Compose responsibilities to the Kubernetes objects introduced next.

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

## Prerequisites

From the repository root:

```bash
docker version
docker compose version
```

If either command fails, start Docker before continuing. You do not need Go,
Python, Node.js, PostgreSQL, or Redis installed on the host; the images contain
their build tools and runtime dependencies.

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
cd stages/launchpad
docker compose up --build -d
docker compose ps
```

Wait until the three PostgreSQL containers and Redis report `healthy`. The app
containers should be `Up`; first-time image builds can take several minutes.

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
```

Log in with the seeded passenger account:

```bash
curl -s -X POST http://localhost:8080/api/users/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"passenger@apolloairlines.com","password":"pass123"}'
```

The response should contain a JWT. The browser UI uses the same identity,
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

Dozzle provides an optional browser log view at <http://localhost:8085>. The
CLI remains the canonical path because it works in every environment.

## 5. Break readiness, then recover

The flight API depends on PostgreSQL. Stop that database deliberately:

```bash
docker compose stop flight-db
curl -i http://localhost:8081/healthz
curl -i http://localhost:8081/readyz
```

`/healthz` answers whether the process is alive. `/readyz` answers whether it
can serve correctly with its dependency available. Inspect the evidence:

```bash
docker compose logs --tail=80 flight flight-db
```

Restore the dependency and watch recovery:

```bash
docker compose start flight-db
docker compose ps
curl -i --retry 15 --retry-delay 2 --retry-all-errors \
  http://localhost:8081/readyz
```

This distinction becomes Kubernetes liveness and readiness behavior in Stage 4.

## 6. Prove database persistence

Named Compose volumes survive container replacement:

```bash
docker compose exec identity-db \
  psql -U postgres -d identity -c 'SELECT count(*) FROM users;'
docker compose stop identity-db
docker compose rm -f identity-db
docker compose up -d --wait identity-db
docker compose exec identity-db \
  psql -U postgres -d identity -c 'SELECT count(*) FROM users;'
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

## Before Ignition

You should be able to answer:

1. Why does booking call `http://flight:8081` instead of `localhost:8081`?
2. What is the difference between a container image and a running container?
3. Why can `/healthz` succeed while `/readyz` fails?
4. Which data survives `docker compose down`, and what removes it?
5. Which Compose features become Deployments, Services, ConfigMaps, Secrets,
   probes, and PVCs in Kubernetes?

Next, continue to [Ignition](../ignition/README.md), where the first container
runs as a Kubernetes Pod.
