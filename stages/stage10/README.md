---
title: "Stage 10 — Mission Extensions (planned optional missions)"
description: "Status and intended modular shape for advanced Apollo Airlines operational extensions."
---

# Stage 10: Mission Extensions

> **Status: not implemented. Do not apply the files currently in this directory.**

The approved mission catalog is defined in [`ROADMAP.md`](../../ROADMAP.md).

The existing files contain unverified legacy scaffolding from a different
application. Stage 10 will be rebuilt from the last trusted Apollo Airlines
snapshot.

This stage is not one linear prerequisite chain. It will be a set of optional,
independently runnable missions:

- service mesh and mTLS with Linkerd;
- progressive delivery with Argo Rollouts;
- live debugging with ephemeral containers and Kubeshark traffic inspection;
- advanced disaster recovery building on the required Stage 9 Velero lab; and
- controlled failure experiments with Chaos Mesh.

Lifecycle hooks move to Stage 4, and the baseline DevSecOps pipeline moves to
Stage 8. They are not introduced here as new concepts.

Each mission must begin with a working baseline, introduce one mechanism, run
an observable experiment, and return the cluster to the baseline. A learner
should not need to install every extension to complete the core curriculum.
