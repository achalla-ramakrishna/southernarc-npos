# ADR-0011: Installation and release management

- Status: Proposed
- Date: 2026-10-11
- Scope: Platform

## Context

nPOS runs as separate installations from one codebase: Northern Arc's own,
and South Indian Bank's inside the bank's environment (discovery O10). More
bank installations are expected (the SRS sizes for up to 25 co-lending bank
tenants), some hosted by Northern Arc and some on bank premises.

Today, "same codebase" covers only the Java services. The behaviour that
differs between partners lives outside Git: BRE rules are Python files
uploaded through the UI, and partner set-up is applied as SQL release
documents (O1, O3). Releases are manual and need downtime (O4). As a result:

- Two installations can run the same build and behave differently, with no
  record of the difference.
- Installations are likely on different versions, so fixes need back-porting
  and the team supports several versions without having decided to.
- Bank-specific changes can creep in as code branches or forks.
- Each release must work with every installation's configuration, but nothing
  tests that automatically (O7).
- Northern Arc has limited visibility of a bank installation's health.
- When Northern Arc co-lends with a bank on its own installation, one loan
  spans two installations.

Banks often require their own installation for RBI outsourcing, data
localisation and their own security controls, so separate installations are
a requirement to manage, not a choice to undo.

## Decision

### 1. One product, one main branch

- All installations are built from one main branch. There are **no
  per-customer branches or forks**, and no code conditions on installation or
  bank name.
- Installation-specific behaviour is allowed only through:
  - **Configuration** (partners, programs, rule sets, journeys), delivered as
    configuration packages (ADR-0010).
  - **Defined extension points** with a published interface, for example the
    core-banking adapter, the `CredentialProvider` for a bank's identity
    provider and gateway (ADR-0009), and notification providers.
  - **Feature flags** scoped to an installation or tenant, with an owner and a
    removal date.
- A code review check rejects installation-name conditions.

### 2. Identical, versioned release artefacts

- Each release is a semantic version (`MAJOR.MINOR.PATCH`) made of signed
  container images and one Helm chart. Every installation runs exactly these
  artefacts.
- The only per-installation input is a **values file** (endpoints, sizing,
  identity provider, enabled extensions, feature flags) plus the
  installation's configuration packages.
- Images are published to a registry each installation can pull from, or are
  exported as a signed offline bundle for air-gapped bank environments.

### 3. One Git repository per installation (GitOps)

Each installation has its own repository holding:

- the release version it runs,
- its Helm values file,
- its configuration packages (exported from Module 1 and later modules),
- its deployment history.

Argo CD applies it where the installation allows. Where the bank's team
deploys, they apply the same repository through their own change process.
Either way, what runs is exactly what is in the repository, and two
installations can be compared with a diff.

### 4. Support-window policy

- **Supported versions:** the current minor release and the previous one
  (N and N-1). Security fixes are back-ported to N-1 only.
- **Upgrade obligation:** every installation upgrades to a supported
  version within **6 months** of a release. This is written into bank
  contracts.
- **Upgrade path:** every release ships tested upgrade migrations from N-1
  (backward-compatible Flyway changes; expand-then-contract for breaking
  schema changes), so an upgrade never needs downtime or manual SQL.
- **Patch releases** contain fixes only, never new behaviour.

### 5. Installation matrix in CI

- The main branch's CI pipeline runs the regression pack against **each
  installation's current configuration packages**, on the release candidate
  and on that installation's next upgrade path (its current version to N).
- A release is not published until every live installation's matrix row
  passes, or the failure is accepted and recorded for that installation.
- Configuration packages are refreshed into CI whenever an installation
  changes its configuration, so the matrix tests what actually runs.

### 6. Installation registry

Northern Arc keeps one registry (a small service or a maintained document,
then a Module 14 view) recording for each installation:

- owner organisation, hosting model (hosted / on-premise), environments,
- release version, date upgraded, next upgrade due,
- configuration package versions,
- enabled extensions and feature flags,
- who deploys and the escalation contacts,
- telemetry status.

### 7. Health telemetry with consent

Each installation can export **operational metrics only** (request rates,
error rates, latency, queue depths, stuck-loan counts, version), with **no
personal or loan-level data**, to Northern Arc's support monitoring.
This is enabled per installation with the bank's written consent and can be
switched off by the bank. Logs and traces stay inside the installation.

### 8. Contract between installations

When a loan involves two installations (for example Northern Arc co-lending
with a bank on its own installation), the installations talk through a
**versioned inter-installation API and event contract** (allocation request,
funding instruction, apportionment and reconciliation files), never by sharing
databases. The contract follows the same N / N-1 compatibility rule as
releases.

### 9. Default offer

New bank tenants are offered **hosted multi-tenant** by default (ADR-0003).
A separate installation is provided when the bank requires it. Every extra
installation adds release, testing and support cost, and the commercials
should reflect that.

## Alternatives considered

- **Per-bank branches or forks.** Fast for the first bank, but every fix has
  to be merged N times, and installations drift permanently. This is the
  failure mode this ADR exists to prevent.
- **Allowing each installation to run any version indefinitely.** Bank
  teams favour it, but support cost grows with every version kept alive, and
  security fixes cannot be guaranteed.
- **Only hosted multi-tenant, no bank installations.** Simplest to operate,
  but some banks will not accept it, which would lose them as customers.
- **Keeping partner logic as uploaded scripts per installation.** This is the
  current situation. It leaves the behaviour that matters most untracked and
  untested.

## Consequences

- Bank contracts need an upgrade clause, a telemetry consent clause, and a
  defined support window.
- Releases become a product discipline: release notes, compatibility notes and
  upgrade guides for every version.
- CI cost grows with the number of installations. This is accepted, because
  the matrix replaces manual testing per installation.
- Moving the **existing** platform to this model needs a one-off step first:
  inventory each installation's version, any bank-specific code, and its
  per-partner Python and SQL, then reconcile them (see open questions below).

## Open questions (to confirm with Northern Arc)

| # | Question |
|---|---|
| IQ1 | Is South Indian Bank's installation on the same version as Northern Arc's today? If not, how far behind? |
| IQ2 | Is there any SIB-specific code: branches, forks or conditions? |
| IQ3 | How do SIB's partner Python files and SQL changes reach its installation, and who deploys there? |
| IQ4 | Can Northern Arc see SIB's logs and monitoring today? |
| IQ5 | Are there, or will there be, other bank installations? Hosted or on-premise? |
| IQ6 | Does SIB's environment allow pulling images from a registry, or does it need offline bundles? |
| IQ7 | Does Northern Arc co-lend with SIB across the two installations today, and how are loans exchanged? |

## Related

- ADR-0001 Technology baseline (Kubernetes, Helm, Argo CD)
- ADR-0003 Multi-tenancy model (an on-premise installation is one tenant)
- ADR-0009 Partner credentials (`CredentialProvider` extension point)
- ADR-0010 Configuration packages
