---
title: "Stage 9 — Lunar Orbit (planned)"
description: "Status and learner-first implementation boundary for the future cloud operations stage."
---

# Stage 9: Lunar Orbit

> **Status: not implemented. Do not apply the files currently in this directory.**

The existing `code/`, `k8s/`, and Terraform files are unverified legacy
scaffolding. They are not a trusted Apollo Airlines continuation.

The standalone [`stages/eks`](../eks/README.md) module is the current cloud
prototype. It has been structurally reviewed but has not been applied to a real
AWS account from this environment.

## Planned learner journey

Use one cloud provider as the primary end-to-end lab before adding a portability
comparison:

1. plan and provision the cluster, then identify every billable resource;
2. deploy the already-known Apollo Airlines platform with cloud LoadBalancer
   and dynamic block storage behavior;
3. generate load and observe both Pod and node scaling;
4. drain or replace a node and measure application availability;
5. perform a controlled cluster upgrade with pre/post checks; and
6. destroy the environment and prove that load balancers, disks, addresses,
   and node resources leave no billable residue.

GKE should be a later portability mission rather than a second simultaneous
implementation. High availability is complete only when failure drills prove
the intended behavior.
