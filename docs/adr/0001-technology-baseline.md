# ADR-0001: Technology baseline

- Status: Proposed
- Date: 2026-10-11
- Scope: Platform

## Context

nPOS must run hosted by Northern Arc and inside banks' own data centres, pass
SOC 1 / SOC 2 audits, keep data in India, and be maintainable by a Java team.
Northern Arc's existing services and disbursement code are Java. Banks that
install nPOS expect mainstream, supported technology their own teams can
operate. The current system runs 20+ services on one VM with downtime on every
release (discovery O4).

## Decision

| Concern | Choice |
|---|---|
| Backend | Java 25 LTS, Spring Boot 4, Spring Cloud; one deployable per service |
| Frontend | React 19 + TypeScript (Vite): a back-office console and a partner portal |
| Database | MySQL 8.4 LTS, Flyway migrations |
| Messaging | Apache Kafka 4 with Schema Registry; Debezium for the outbox |
| Cache | Redis |
| Identity | Keycloak (OIDC, MFA, federation), Spring Security, mTLS for partners |
| Gateway | Spring Cloud Gateway |
| Runtime | Kubernetes (OpenShift-compatible), Helm, Argo CD |
| Observability | OpenTelemetry, Prometheus, Grafana, Loki, Tempo |
| Secrets | HashiCorp Vault |
| Testing | JUnit 5, Testcontainers, Pact, Playwright, k6 |

Workflow (Temporal vs Camunda 8) and rules (DMN on Apache KIE) are decided in
their own ADRs with Modules 4 and 2.

## Alternatives considered

- **PostgreSQL instead of MySQL.** Technically strong, but MySQL is the
  stated preference and is widely run by Indian banks' DBA teams.
- **A modular monolith instead of microservices.** Simpler to run, but the
  requirement is microservices, and runtime isolation between partners and
  independent releases are explicit goals (O3, O4). Inside each service we
  still keep a modular structure.
- **Managed cloud services (for example Amazon MSK or RDS) as hard
  dependencies.** These do not work in on-premise bank installations. We use
  open-source components that have managed equivalents, behind standard
  protocols.

## Consequences

- One stack runs in both deployment models; Helm values differ per
  installation, code does not.
- The team needs Kubernetes and Kafka skills; Module 0 includes local
  development tooling (Docker Compose or kind) so developers do not need a cluster.
- Version upgrades (Java, Spring Boot, MySQL) are planned yearly and tested
  against every installation.
