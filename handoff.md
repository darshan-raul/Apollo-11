---
title: "Apollo11 — Current Handoff"
description: "Canonical resume point for the learner-roadmap migration and evidence-driven stage rebuild."
---

# Apollo11 current handoff

Updated: 2026-09-04

This file is the concise operational handoff for the next session. Use
`ROADMAP.md` for the approved curriculum architecture, `AGENTS.md` for project
contracts and stage details, and each stage README for learner instructions.
Older completion notes remain available in Git history; they are not repeated
here because several described a curriculum structure that has since changed.

## Current position

- Branch: `main`.
- The roadmap remap and retirement of the legacy Stage 8 tree were committed
  and pushed as `244b037` (`docs: remap learning roadmap and retire stage 8`).
- The Launchpad migration pass described below is complete, verified, and
  committed together with this handoff.
- No temporary Launchpad containers, volumes, or networks remain.
- The next curriculum migration checkpoint is **Ignition**, followed by
  **Stage 1**. Do not jump directly to rebuilding Stage 8.
- Stages 1–7 remain the last existing runnable Kubernetes path while the
  curriculum is migrated one phase at a time.
- Stage 8 has intentionally been deleted. Its replacement must be rebuilt from
  the latest verified Stage 7 Helm baseline and receives no trust from the old
  implementation.
- Stage 9, Stage 10, Stage 11, and `stages/eks` remain planned, optional, or
  prototype material as labeled in `ROADMAP.md` and `AGENTS.md`.

## Approved roadmap decisions

The roadmap was stress-tested in a 45-question grill and approved before any
stage restructuring began. The durable decisions are:

1. The required learner path is Launchpad → Ignition → Stages 1–9.
2. Stages 10 and 11 are optional mission/specialization catalogs with explicit
   prerequisites, not a mandatory linear continuation.
3. Every required substage follows **Build → Inspect → Break → Recover →
   Explain**. Automation is the reproducible answer key, not the learner's only
   interaction.
4. Each phase keeps one independently runnable snapshot. Ordered manifests,
   patches, or scripts represent substages instead of duplicating full trees.
5. Raw Kubernetes resources remain the primary learning surface through Stage
   4. Helm becomes canonical after Stage 5; Kustomize remains a required
   comparison lab rather than a permanently parallel platform definition.
6. Troubleshooting starts in Ignition and grows through status, events,
   `describe`, logs, endpoints, metrics, traces, and policy decisions.
7. Stage 2 preserves the access ladder: ClusterIP/DNS → NodePort → Traefik
   Ingress/TLS → MetalLB → Envoy Gateway API. Envoy becomes the later-stage
   baseline. The Traefik dashboard is optional/reference material.
8. Headless Services are introduced with StatefulSets in Stage 3, not earlier.
9. NetworkPolicy is taught only when enforcement can be demonstrated. The
   current kindnet reference manifests must not be advertised as enforced;
   Calico enforcement belongs in the rebuilt Stage 8.
10. Scheduling concepts previously introduced in Stage 7 move to Stage 4,
    alongside requests, QoS, disruption, and placement.
11. Stage 7 begins with repeatable k6 measurements, then cache-aside behavior,
    HPA, VPA recommendations, and tradeoff analysis.
12. Stage 8 is a clean security rebuild: workload/RBAC hardening, Calico
    NetworkPolicy, Vault plus External Secrets Operator, and Kyverno/Trivy/
    Cosign supply-chain enforcement.
13. Stage 9 is an AWS/EKS-first real-account lifecycle and capstone, including
    cost gates, identity, storage, DNS/TLS, scaling, node failure, upgrade,
    Velero restore, and ownership-scoped teardown. GKE is a required
    portability analysis and an optional second deployment.
14. No stage is marked complete from inert manifests, static renders, or old
    pass counts. Trust requires a fresh lifecycle and observable behavior.

The authoritative details, migration matrix, and correction backlog are in
`ROADMAP.md`.

## Launchpad migration — complete

### Runtime and configuration

- Added `stages/launchpad/.env.example` with `POSTGRES_USER`,
  `POSTGRES_PASSWORD`, and `JWT_SECRET`.
- Updated `.gitignore` to ignore `.env` files while retaining `.env.example`.
- Compose now refuses to render without the required credential variables.
- The default Compose profile contains exactly the ten Apollo Airlines
  workloads. Dozzle moved behind the optional `tools` profile because Docker
  socket access is privileged even with a read-only bind mount.
- All six application containers have health checks and dependency-aware
  startup ordering.

### Container hardening

- All backend Dockerfiles and the frontend runtime declare non-root users.
- Each application service receives a read-only root filesystem, writable
  `/tmp` tmpfs, `no-new-privileges`, and `cap_drop: [ALL]` in Compose.
- Added narrow `.dockerignore` files for backend build contexts.
- The frontend uses `npm ci`, an explicit non-root-compatible NGINX
  configuration, and `/healthz`, `/readyz`, and `/metrics` endpoints.
- Do not mistake these defaults for completion of the security curriculum;
  Stage 8 later makes them explicit, observable, and attackable in Kubernetes.

### Application correctness and observability

- Corrected the invalid `:import os` token in Identity.
- Identity now uses `bcrypt` directly, removing the noisy/incompatible Passlib
  wrapper while retaining existing bcrypt hashes.
- All six applications expose Prometheus text instead of JSON at `/metrics`.
  These are deliberately minimal baseline metrics; real instrumentation and
  collection arrive in Stage 6.
- Search readiness now checks Flight readiness.
- Booking readiness now checks PostgreSQL, Identity, Flight, and Notification.
- Notification's Redis startup wait is bounded to ten seconds and degrades
  cleanly rather than retrying forever.
- Booking forwards the caller's JWT to Identity and generates a short-lived
  `SERVICE` JWT for Flight seat mutations.
- Flight seat mutation accepts the internal `SERVICE` role or an administrator.
  Flight and Booking restrict JWT parsing to HS256.

### Frontend dependency state

- Repaired the stale lockfile that omitted `react-hot-toast` transitive data.
- Updated React Router, Vite, and the Vite React plugin to their audited current
  compatible releases used by the successful container build.
- `npm audit` reports zero vulnerabilities.
- The tracked `dist/` snapshot was restored after verification; source builds
  do not leave generated Vite hashes in the worktree.

### Learner experience

`stages/launchpad/README.md` now provides the complete learner loop:

- create the local `.env` file and start the ten-workload stack;
- inspect health, readiness, metrics, DNS, logs, users, and filesystem controls;
- log in and create a confirmed booking across the flagship dependency path;
- stop Flight PostgreSQL and observe readiness propagation;
- recover the database and prove behavioral recovery;
- replace an Identity database container and prove volume persistence;
- optionally launch Dozzle with an explicit Docker-socket warning; and
- answer the final concept questions before Ignition.

The root README and `AGENTS.md` describe the same verified boundary.

### Automated verifier

Added executable `stages/launchpad/scripts/verify.sh`. It checks:

- ten default workloads and the optional Dozzle profile boundary;
- health, non-root execution, read-only filesystems, no privilege escalation,
  dropped capabilities, and writable `/tmp` for all six applications;
- `/healthz`, `/readyz`, and all three required metric names;
- seeded-passenger login;
- confirmed booking creation and cancellation; and
- request-ID evidence in service logs.

Final isolated run:

```text
Launchpad verification: 73 passed, 0 failed
```

Additional manual evidence:

- With `flight-db` stopped, Flight health/readiness, Search readiness, and
  Booking readiness returned `200 / 503 / 503 / 503` respectively.
- After restarting the database, all three readiness endpoints recovered to
  `200`.
- Identity's seeded user count remained `2` before and after replacing its
  database container, proving the named volume boundary.
- The four Go services passed `go test ./...`.
- Identity passed `python3 -m py_compile main.py`.
- The frontend production build passed and `npm audit` reported zero findings.
- Compose rendering, default-service enumeration, shell syntax, and
  `git diff --check` passed.
- The final isolated project `apollo11-launchpad-final` was removed with its
  volumes and network; the residue query returned nothing.

## Important carry-forward constraints

- Each stage owns a self-contained `code/` snapshot. Do not mechanically copy
  the Launchpad tree over Stage 1 or later snapshots. Audit the destination's
  existing correctness fixes, then port only the appropriate baseline behavior.
- Keep example secrets out of real `.env` files. Launchpad database passwords
  should use URL-safe characters because Compose embeds them in connection URLs.
- PostgreSQL initialization credentials apply only to an empty data directory.
  If credentials change after first startup, intentionally recreate the local
  volumes as documented.
- Do not expand the skeleton metrics into a home-grown monitoring system during
  early stages. Stage 6 owns real counters, histograms, scraping, dashboards,
  logs, traces, alerts, and SLO evidence.
- Do not apply reference NetworkPolicies on kindnet or claim enforcement.
- Preserve the Envoy Gateway plus MetalLB access baseline from Stage 2 set 5
  once later stages are reached.
- Do not use the deleted Stage 8 implementation or the legacy Stage 9/10/11
  scaffolding as a trusted source.
- Do not create commits or push unless the user explicitly requests that
  specific action.

## Exact next-session sequence

### 1. Confirm the handoff boundary

```bash
git status --short
git log -2 --oneline
```

The worktree should be clean and the latest commit should contain the Launchpad
closure and this handoff.

### 2. Audit Ignition against the approved roadmap

Read, in order:

1. `ROADMAP.md` — Ignition target and migration matrix entry.
2. `AGENTS.md` — learner-first lab contract and current project facts.
3. `stages/ignition/README.md` and every referenced manifest/script.

Produce a concrete gap list before editing. The required outcome is a reusable
troubleshooting evidence ladder plus a safe Pod failure/reconciliation exercise
with behavioral recovery proof. Preserve the corrected imperative-to-
declarative Pod sequence already present.

### 3. Implement and verify Ignition

- Keep the increment minimal and learner-visible.
- Validate shell/YAML statically first.
- Use a fresh kind lifecycle for runtime claims.
- Capture exact Build/Inspect/Break/Recover evidence.
- Tear down or explicitly document retained resources and audit residue.
- Update README/AGENTS completion claims only after the lifecycle passes.

### 4. Continue to Stage 1

After Ignition is trusted, audit Stage 1 against the roadmap. The main gaps to
close are:

- observable Deployments, ReplicaSets, labels/selectors, and Services;
- ConfigMaps, Secrets, namespace, and meaningful workload ServiceAccounts;
- one-shot database initialization Jobs;
- rolling update, failed rollout diagnosis, and rollback; and
- a clean apply → inspect → break → recover → teardown lifecycle.

### 5. Continue phase-by-phase

Proceed through the migration matrix in `ROADMAP.md`. Rebuild one boundary at a
time, preserve the last runnable path, and never promote an external/cloud
stage without exercising the real external lifecycle and cleanup.
