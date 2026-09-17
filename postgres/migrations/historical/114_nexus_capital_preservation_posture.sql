BEGIN;
SET LOCAL lock_timeout = '5s';

INSERT INTO nexus.portfolio_decision_contexts(
    portfolio_decision_context_id,context_as_of,portfolio_value_basis,captured_securities_value,
    deployable_cash,settled_cash,debt_priority_state,emergency_reserve_state,deployment_authorized,
    source_note,created_by
) SELECT
    '11400000-0000-4000-8000-000000000001','2026-09-15T22:21:25.343Z',
    'September 15 authenticated Fidelity and Chase securities observations plus Financial Tracker v.13 household-capital constraints',
    sum(market_value),0,NULL,'binding','shortfall',false,
    'Financial Tracker v.13 was updated 2026-09-15T22:21:25.343Z and reports $746.51 cash, a Cash Low alert below $1,000, $31,697.26 active debt, and a $6,594.23 working monthly-bills total that is not a verified required-payment total. Fidelity 1093 showed $0.17 account cash and Chase 1660 showed $0.00 account cash, but current settled cash and available-to-trade cash were not refreshed. Policy-deployable cash is therefore $0; this is a governance constraint, not a claim that every account balance is zero. Deployment is not authorized. Source: https://docs.google.com/spreadsheets/d/13_iUG4H8r-X_4W24fs0-YnBLceCw6dIJGssWfFrVOV0/edit',
    'nexus_migration_114'
FROM nexus.v_consolidated_portfolio_snapshot;

WITH current_assessments AS (
    SELECT a.*,i.ticker,
           row_number() OVER (ORDER BY i.ticker) AS sequence_number
    FROM nexus.v_decision_engine_assessment_current a
    JOIN nexus.instruments i USING(instrument_id)
)
INSERT INTO nexus.decision_engine_assessments(
    decision_engine_assessment_id,decision_engine_policy_id,portfolio_decision_context_id,
    portfolio_lane_id,instrument_id,lane_review_id,primary_review_evidence_id,recommendation,
    readiness,conviction_level,thesis_state,valuation_state,concentration_state,overlap_state,
    liquidity_state,debt_priority_state,emergency_reserve_state,captured_market_value,
    captured_portfolio_weight,known_indirect_overlap_value,blockers,rationale,
    next_required_evidence,review_due_on,supersedes_assessment_id,assessed_at,created_by
)
SELECT
    ('11400000-0000-4000-8000-' || lpad((100+sequence_number)::text,12,'0'))::uuid,
    decision_engine_policy_id,'11400000-0000-4000-8000-000000000001',
    portfolio_lane_id,instrument_id,lane_review_id,primary_review_evidence_id,
    CASE WHEN ticker IN ('AVGO','DRAM','IVEP','SPCX','SPYI')
         THEN 'watch'::nexus.decision_type ELSE 'hold'::nexus.decision_type END,
    'conditional',NULL,'research','insufficient',concentration_state,'measured_partial',
    'constrained','binding','shortfall',captured_market_value,captured_portfolio_weight,
    known_indirect_overlap_value,
    array_remove(ARRAY[
        'current_valuation_basis_incomplete','new_deployment_blocked_by_debt_priority',
        'emergency_reserve_shortfall','broker_settled_cash_not_refreshed',
        'portfolio_overlap_not_decision_grade','lane_role_not_approved',
        CASE WHEN concentration_state='high' THEN 'high_captured_concentration' END,
        CASE WHEN concentration_state='elevated' THEN 'elevated_captured_concentration' END
    ],NULL),
    CASE WHEN ticker IN ('AVGO','DRAM','IVEP','SPCX','SPYI') THEN
        'Conditional watch posture for the existing position. No new capital is authorized while debt priority is binding and the emergency reserve is below the current working-obligation baseline. Watch does not authorize a purchase, sale, transfer, or position-size change.'
    ELSE
        'Conditional hold posture for the existing position. No new capital is authorized while debt priority is binding and the emergency reserve is below the current working-obligation baseline. Hold does not authorize a purchase, sale, transfer, or position-size change.'
    END,
    'Refresh settled cash and available-to-trade balances directly from the broker; establish an adequate emergency-reserve target and debt-clearance rule; complete a dated valuation, security-liquidity review, direct-plus-fund overlap review, and authenticated lane-role review before any proposal.',
    (clock_timestamp()+interval '30 days')::date,decision_engine_assessment_id,clock_timestamp(),
    'nexus_migration_114'
FROM current_assessments;

COMMENT ON TABLE nexus.portfolio_decision_contexts IS 'Immutable portfolio-capital context. Deployable cash is a policy amount and can be zero even when observed account cash is nonzero; unknown settled cash remains NULL.';

COMMIT;
