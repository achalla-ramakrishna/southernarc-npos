# nPOS (Northern Arc Loan Origination Platform): target-state build

This repository holds the target-state design and, later, the implementation of
a microservices-based loan origination and co-lending platform modelled on
Northern Arc's nPOS. The design follows the SRS work done for the Northern Arc
engagement (CodeWalnut) and the problems seen in discovery.

> Status: **design phase**. No code yet. We are working module by module:
> scope, domain model and decisions are agreed first, and implementation comes after.

## Document map

| Document | What it covers |
|---|---|
| [docs/context.md](docs/context.md) | What nPOS is, the business models, and the problems found in discovery |
| [docs/architecture/platform-overview.md](docs/architecture/platform-overview.md) | Architecture principles, tech stack, module list and build order |
| [docs/adr/](docs/adr/) | Architecture decision records (platform-wide and per module) |
| [docs/modules/01-partner-program/](docs/modules/01-partner-program/) | Module 1: Partner and Program Management (scope, domain model) |

## How we work through each module

1. **Scope**: which use cases are in and out, actors, dependencies.
2. **Domain model**: aggregates, lifecycles, invariants.
3. **Decisions**: ADRs for every choice that is costly to reverse.
4. **Contracts**: OpenAPI for REST, schemas for events.
5. **Data model**: MySQL schema and Flyway migrations.
6. **Screens**: the React back-office screens the module needs.
7. **Implementation**, in small, tested slices.

Each step is reviewed before the next one starts.

## Source material

The SRS, use case specifications, NFRs and discovery minutes are in the
engagement's Google Drive folder ("Software Requirement Specifications",
"UP-01 … UP-13"). The docs here cite use case IDs (UC-xx.yy), business rule IDs
(BR-xx.yy-nn) and NFR IDs (NFR-UP01-xx) from that material.
