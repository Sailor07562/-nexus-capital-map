# Promotion Protocol 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-PROMOTION-001

Status: GOVERNED — NO PROMOTION BY DEFAULT

## Gate Sequence

1. Define the exact artifact, source, target, and intended action in text.
2. Verify the operating mode and access path.
3. Capture or reference the applicable freeze/checkpoint and backup manifest.
4. Run only approved read-only validation checks first.
5. Present evidence, risk, rollback path, and proposed execution text.
6. Obtain explicit Captain authorization for the exact target and action.
7. Execute only the authorized scope.
8. Perform readback verification and record the result.

## Stop Conditions

Stop and return to the Captain when any of the following is missing:

- verified target identity
- applicable freeze/checkpoint or recovery trail
- safe rollback path
- required redaction
- exact authorization for a live, destructive, authority-moving, or promotion action

## Record Required After Promotion

- timestamp and operator
- source and target
- artifact/version or commit reference
- validation evidence
- authorization reference
- readback result
- rollback result, if invoked

