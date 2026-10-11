# CLAUDE.md

Guidance for Claude Code sessions in this repository.

- Start with `README.md` for the document map, then `docs/context.md` for the
  business background.
- The design is agreed module by module. Do not write implementation code for a
  module until its scope, domain model and ADRs in `docs/` are agreed.
- Use the IDs from the SRS (UC-xx.yy, BR-xx.yy-nn, NFR-UP01-xx) when referring
  to requirements, so documents and code stay traceable.
- Record decisions that are costly to reverse as ADRs in `docs/adr/`, numbered
  sequentially, using the format of the existing records.
- Target stack: Java 25, Spring Boot 4, React 19 + TypeScript, MySQL 8.4,
  Kafka, Keycloak, Kubernetes. See `docs/architecture/platform-overview.md`.
- Treat partner-specific behaviour as configuration, never as partner-specific
  code branches. This is the core lesson from discovery.
