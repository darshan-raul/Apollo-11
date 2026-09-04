---
title: "Stage 11 — Towards Mars (planned optional specializations)"
description: "Status and intended modular shape for advanced Kubernetes specialization labs."
---

# Stage 11: Towards Mars

> **Status: not implemented. Do not apply the files currently in this directory.**

The approved specialization catalog is defined in
[`ROADMAP.md`](../../ROADMAP.md).

The existing files contain unverified legacy library-management scaffolding.
They are not compatible with the trusted Apollo Airlines stages.

Stage 11 will be a menu of advanced specializations rather than a single final
deployment:

- build and reconcile an Apollo flight-status CRD and controller;
- scale booking from an observable event source with KEDA;
- operate Apollo Airlines on a k3s homelab;
- expose a paved developer workflow through Backstage;
- inspect and reduce cluster cost with Kubecost; and
- explore Cluster API in its own disposable management/workload-cluster lab.

Each specialization must define its own prerequisites, cost/resource budget,
failure exercise, verification, and cleanup. Completing one should not require
installing all the others.
