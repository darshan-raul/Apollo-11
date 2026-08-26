---
title: "Stage 8 — Command Module Hardening (planned)"
description: "Status and learner-first implementation boundary for the future Apollo Airlines security stage."
---

# Stage 8: Command Module Hardening

> **Status: not implemented. Do not apply the files currently in this directory.**

The existing `code/` and partial `k8s/` trees are legacy scaffolding from a
different application. They are not a continuation of the verified Apollo
Airlines Stage 7 snapshot and are retained only until Stage 8 is rebuilt.

## Planned learner journey

Stage 8 will be implemented as observable security exercises, not as one large
bundle of security products:

1. attempt an API action with the current ServiceAccount, then introduce
   least-privilege RBAC and prove allowed and forbidden requests;
2. run a deliberately insecure Pod, harden it with Pod and container
   SecurityContexts, and prove the insecure shape is rejected;
3. enable NetworkPolicy enforcement with a compatible CNI, apply default deny,
   observe the booking workflow fail, add minimum allow rules, and prove
   recovery;
4. replace ordinary Secret consumption with the chosen external-secret flow;
5. scan an image and enforce the selected admission policy against a known-bad
   workload.

Vault, admission policy, and image scanning may be delivered as separate
missions if combining them would obscure the core Kubernetes behavior.

## Trusted starting point

Rebuild this stage from `stages/stage7/`. Preserve both Helm and Kustomize
delivery paths, the observability stack, the Stage 7 cache/autoscaling
behavior, and clean lifecycle verification. Do not copy the legacy service
names (`auth`, `catalog`, `circulation`, or `fines`) forward.
