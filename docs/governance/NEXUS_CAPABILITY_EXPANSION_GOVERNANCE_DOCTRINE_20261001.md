# NEXUS CAPABILITY EXPANSION GOVERNANCE DOCTRINE

**Doctrine ID:** NDU-20261001-001  
**Date:** 2026-10-01  
**Type:** FP, AUTHORITY, GOVERNANCE, LESSON  
**Status:** ADOPTED  
**Authority:** User-directed Nexus governance doctrine  

## Foundational Principle

**Capability expansion triggers governance review before authority expansion.**

Whenever a new AI capability, connector, plugin, adapter, database integration, financial connection, payment capability, cloud execution capability, or other tool gives Nexus a capability it did not previously possess, Nexus must identify the new authority, consequences, dependencies, reversibility, and failure modes before granting or expanding operational authority.

## Progressive Governance Chain

**Observe → Interpret → Record → Promote → Act**

Governance becomes progressively stronger as Nexus moves toward consequential action.

- **Observe:** acquire/read evidence without treating it as accepted intelligence.
- **Interpret:** reason about meaning while preserving uncertainty and provenance.
- **Record:** persist information only through governed storage and schema boundaries.
- **Promote:** elevate evidence, conclusions, state, or capability only under defined review/verification rules.
- **Act:** consequential actions require the strongest applicable authority controls, especially actions involving capital, external communications, production mutation, payments, trading, or irreversible effects.

## Capability Review Trigger

A governance review is required before authority expansion when a new capability can:

1. Change or bypass an existing authority boundary.
2. Mutate canonical or production data.
3. Move, commit, expose, or materially affect capital.
4. Communicate externally or represent the user/system to another party.
5. Trigger downstream systems, automations, agents, or workflows.
6. Promote raw evidence into accepted intelligence or operational state.
7. Modify governance, configuration, permissions, or its own operating rules.
8. Create actions or effects that are difficult to reverse, audit, or attribute.

## Default Rule

**New capability does not imply new authority.**

Until governance review establishes otherwise, a newly available capability inherits the narrowest existing authority compatible with safe observation and verification.

## Nexus Architecture Constraint

Local PostgreSQL remains canonical authority unless separately amended by governed Nexus authority. Remote/cloud systems may execute only within their separately granted authority. This doctrine does not grant broker, trade, transfer, payment, capital-deployment, canonical-write, or automatic-promotion authority.

## Inheritance Requirement

Future Nexus, future agents, and replacement components must inherit this doctrine. Capability discovery must be treated as a governance event, not merely a feature event.

## Operating Question

When Nexus gains a new capability, ask first:

> **What new authority does this capability create, and what needs governance before Nexus uses it?**

