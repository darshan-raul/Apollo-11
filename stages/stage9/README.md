---
title: "Stage 9 — Lunar Orbit (planned)"
description: "Status and learner-first implementation boundary for the future cloud operations stage."
---

# Stage 9: Lunar Orbit

> **Status: not implemented. Do not apply the files currently in this directory.**

The approved target and migration boundary are defined in
[`ROADMAP.md`](../../ROADMAP.md).

The existing `code/`, `k8s/`, and Terraform files are unverified legacy
scaffolding. They are not a trusted Apollo Airlines continuation.

The standalone [`stages/eks`](../eks/README.md) module is research input only.
It trails the trusted curriculum baseline and contains unresolved Terraform,
routing, and teardown defects. It must not be promoted into Stage 9 or treated
as a safe real-account lifecycle.

## Planned learner journey

Use AWS/EKS as the primary end-to-end lab before adding a portability
comparison:

1. build incremental Terraform modules and identify every billable resource;
2. deploy the latest hardened Helm snapshot using ECR, workload identity,
   dynamic storage, cloud load balancing, DNS, and automated TLS;
3. reuse the Stage 7 load model and observe both Pod and node scaling;
4. drain or replace a node and measure application availability;
5. perform a controlled cluster upgrade with pre/post behavioral checks;
6. back up and restore the application with Velero; and
7. destroy the environment and prove that load balancers, disks, addresses,
   registry artifacts, and node resources leave no billable residue.

A required EKS-to-GKE architecture and manifest comparison follows the AWS
lifecycle; hands-on GKE deployment is optional. The capstone describes Apollo11
as production-shaped, not production-ready, and ends with an explicit gap
analysis rather than an unsupported high-availability claim.
