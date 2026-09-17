BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE nexus.research_radar_state_lanes (
    research_radar_state_lane_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    lane_code text NOT NULL UNIQUE CHECK (lane_code ~ '^nexus_research_radar_[a-z]+_lane_[0-9]{3}$'),
    state_code text NOT NULL UNIQUE CHECK (state_code ~ '^[A-Z]{2}$'),
    state_name text NOT NULL UNIQUE CHECK (btrim(state_name) <> ''),
    lane_status text NOT NULL CHECK (lane_status IN ('verified_seeded','suspended','retired')),
    doctrine text NOT NULL CHECK (btrim(doctrine) <> ''),
    utility_regulator text NOT NULL CHECK (btrim(utility_regulator) <> ''),
    iso_rto_names text[] NOT NULL CHECK (coalesce(array_length(iso_rto_names,1),0) > 0),
    major_utilities text[] NOT NULL CHECK (coalesce(array_length(major_utilities,1),0) > 0),
    environmental_agency text NOT NULL CHECK (btrim(environmental_agency) <> ''),
    priority_locations text[] NOT NULL CHECK (coalesce(array_length(priority_locations,1),0) > 0),
    search_terms text[] NOT NULL CHECK (coalesce(array_length(search_terms,1),0) > 0),
    source_chat_id text NOT NULL UNIQUE CHECK (source_chat_id ~ '^[0-9a-f-]{36}$'),
    verification_basis text NOT NULL CHECK (length(btrim(verification_basis)) >= 80),
    verified_at timestamptz NOT NULL,
    human_review_required boolean NOT NULL DEFAULT true CHECK (human_review_required),
    thesis_promotion_allowed boolean NOT NULL DEFAULT false CHECK (NOT thesis_promotion_allowed),
    trade_action_allowed boolean NOT NULL DEFAULT false CHECK (NOT trade_action_allowed),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER prevent_research_radar_state_lane_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.research_radar_state_lanes
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.research_radar_sources (
    research_radar_source_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    research_radar_state_lane_id uuid NOT NULL
        REFERENCES nexus.research_radar_state_lanes ON DELETE RESTRICT,
    source_code text NOT NULL UNIQUE CHECK (source_code ~ '^[a-z0-9][a-z0-9_]*$'),
    source_name text NOT NULL CHECK (btrim(source_name) <> ''),
    source_type text NOT NULL CHECK (source_type IN (
        'utility_regulator','iso_rto','environmental_regulator',
        'transmission_owner','local_government','utility_official'
    )),
    authority_tier text NOT NULL CHECK (authority_tier IN ('A1','A2','A3','B1')),
    source_base_uri text NOT NULL CHECK (source_base_uri ~ '^https://'),
    verification_status text NOT NULL CHECK (verification_status = 'verified_official'),
    verification_basis text NOT NULL CHECK (length(btrim(verification_basis)) >= 40),
    limitations text NOT NULL CHECK (length(btrim(limitations)) >= 40),
    verified_at timestamptz NOT NULL,
    automated_intake_enabled boolean NOT NULL DEFAULT false CHECK (NOT automated_intake_enabled),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_research_radar_sources_lane
    ON nexus.research_radar_sources(research_radar_state_lane_id, authority_tier, source_code);

CREATE TRIGGER prevent_research_radar_source_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.research_radar_sources
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.research_radar_scraper_definitions (
    research_radar_scraper_definition_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    research_radar_state_lane_id uuid NOT NULL
        REFERENCES nexus.research_radar_state_lanes ON DELETE RESTRICT,
    scraper_code text NOT NULL UNIQUE CHECK (scraper_code ~ '^[a-z0-9][a-z0-9_]*$'),
    scraper_name text NOT NULL CHECK (btrim(scraper_name) <> ''),
    source_types text[] NOT NULL CHECK (coalesce(array_length(source_types,1),0) > 0),
    classification_codes text[] NOT NULL CHECK (coalesce(array_length(classification_codes,1),0) > 0),
    execution_status text NOT NULL CHECK (execution_status = 'defined_not_deployed'),
    execution_enabled boolean NOT NULL DEFAULT false CHECK (NOT execution_enabled),
    human_review_required boolean NOT NULL DEFAULT true CHECK (human_review_required),
    trade_action_allowed boolean NOT NULL DEFAULT false CHECK (NOT trade_action_allowed),
    limitations text NOT NULL CHECK (length(btrim(limitations)) >= 60),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER prevent_research_radar_scraper_definition_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.research_radar_scraper_definitions
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.research_radar_signals (
    research_radar_signal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    research_radar_state_lane_id uuid NOT NULL
        REFERENCES nexus.research_radar_state_lanes ON DELETE RESTRICT,
    research_radar_source_id uuid NOT NULL
        REFERENCES nexus.research_radar_sources ON DELETE RESTRICT,
    signal_code text NOT NULL UNIQUE CHECK (signal_code ~ '^[a-z0-9][a-z0-9_]*$'),
    official_record_id text NOT NULL CHECK (btrim(official_record_id) <> ''),
    source_uri text NOT NULL CHECK (source_uri ~ '^https://'),
    source_title text NOT NULL CHECK (btrim(source_title) <> ''),
    source_published_at date,
    retrieved_at timestamptz NOT NULL,
    classification_code text NOT NULL CHECK (classification_code ~ '^[A-Z0-9_]+$'),
    evidence_tier text NOT NULL CHECK (evidence_tier IN ('A1','A2','A3','B1')),
    conviction_start text NOT NULL CHECK (conviction_start IN ('high','medium','watch')),
    queue_status text NOT NULL CHECK (queue_status = 'pending_human_review'),
    factual_summary text NOT NULL CHECK (length(btrim(factual_summary)) >= 80),
    interpretation_note text NOT NULL CHECK (length(btrim(interpretation_note)) >= 80),
    limitations text NOT NULL CHECK (length(btrim(limitations)) >= 60),
    thesis_promotion_allowed boolean NOT NULL DEFAULT false CHECK (NOT thesis_promotion_allowed),
    trade_action_allowed boolean NOT NULL DEFAULT false CHECK (NOT trade_action_allowed),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (research_radar_source_id, official_record_id),
    UNIQUE (research_radar_state_lane_id, research_radar_signal_id)
);

CREATE INDEX idx_research_radar_signals_queue
    ON nexus.research_radar_signals(queue_status, evidence_tier, retrieved_at DESC);
CREATE INDEX idx_research_radar_signals_lane
    ON nexus.research_radar_signals(research_radar_state_lane_id, classification_code);

CREATE TRIGGER prevent_research_radar_signal_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.research_radar_signals
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.research_radar_ticker_links (
    research_radar_ticker_link_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    research_radar_signal_id uuid NOT NULL
        REFERENCES nexus.research_radar_signals ON DELETE RESTRICT,
    ticker text NOT NULL CHECK (ticker = upper(btrim(ticker)) AND ticker ~ '^[A-Z.]{1,10}$'),
    relationship_code text NOT NULL CHECK (relationship_code IN (
        'transmission_grid_watch','electrical_equipment_watch','data_center_infrastructure_watch',
        'backup_power_watch','consumer_stress_watch','constraint_map_watch'
    )),
    link_basis text NOT NULL CHECK (length(btrim(link_basis)) >= 60),
    human_review_required boolean NOT NULL DEFAULT true CHECK (human_review_required),
    thesis_promotion_allowed boolean NOT NULL DEFAULT false CHECK (NOT thesis_promotion_allowed),
    trade_action_allowed boolean NOT NULL DEFAULT false CHECK (NOT trade_action_allowed),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (research_radar_signal_id, ticker, relationship_code)
);

CREATE INDEX idx_research_radar_ticker_links_ticker
    ON nexus.research_radar_ticker_links(ticker, research_radar_signal_id);

CREATE TRIGGER prevent_research_radar_ticker_link_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.research_radar_ticker_links
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

INSERT INTO nexus.research_radar_state_lanes(
    lane_code,state_code,state_name,lane_status,doctrine,utility_regulator,
    iso_rto_names,major_utilities,environmental_agency,priority_locations,
    search_terms,source_chat_id,verification_basis,verified_at,created_by
) VALUES
('nexus_research_radar_virginia_lane_001','VA','Virginia','verified_seeded',
 'News confirms. Filings reveal. Permits whisper first.',
 'Virginia State Corporation Commission',ARRAY['PJM'],
 ARRAY['Dominion Energy Virginia','Appalachian Power'],
 'Virginia Department of Environmental Quality',
 ARRAY['Loudoun County','Prince William County','Fairfax County','Henrico County','Chesterfield County'],
 ARRAY['data center','large load','transmission','substation','interconnection','air permit','cost allocation','ratepayer'],
 '6aaac6bb-cae4-83e8-ba55-79c688590c17',
 'Official Virginia SCC docket, transmission-project and data-center initiative records were rechecked on 2026-09-16; the lane remains an official-record-first human-review queue.',
 '2026-09-16T23:30:00Z','nexus_migration_124'),
('nexus_research_radar_wisconsin_lane_001','WI','Wisconsin','verified_seeded',
 'News confirms. Filings reveal. Permits whisper first.',
 'Public Service Commission of Wisconsin',ARRAY['MISO'],
 ARRAY['We Energies','Wisconsin Public Service','Wisconsin Power and Light','Northern States Power-Wisconsin','Madison Gas and Electric'],
 'Wisconsin Department of Natural Resources',
 ARRAY['Racine County','Mount Pleasant','Kenosha','Port Washington','Ozaukee County','Dodge County'],
 ARRAY['data center','very large customer','transmission','345-kV','air permit','stormwater','water supply','ratepayer'],
 '6aaac8da-f8b0-83e8-8b0c-b84c8eb50263',
 'Official PSCW, Wisconsin DNR and transmission-owner records were rechecked on 2026-09-16; three named records are seeded for human review without thesis promotion.',
 '2026-09-16T23:30:00Z','nexus_migration_124'),
('nexus_research_radar_indiana_lane_001','IN','Indiana','verified_seeded',
 'News confirms. Filings reveal. Permits whisper first.',
 'Indiana Utility Regulatory Commission',ARRAY['MISO','PJM'],
 ARRAY['AES Indiana','Duke Energy Indiana','NIPSCO','Indiana Michigan Power','CenterPoint Energy Indiana'],
 'Indiana Department of Environmental Management',
 ARRAY['Allen County','Fort Wayne','Morgan County','Monrovia','LaPorte County','Michigan City','Clark County','Jeffersonville','Boone County','Lebanon'],
 ARRAY['data center','large load','special contract','transmission','substation','TDSIC','HEA 1007','ratepayer'],
 '6aaac8ad-fa30-83e8-8a7e-fe454fb482ad',
 'Official IURC filings and state and local official source portals were rechecked on 2026-09-16; the dual MISO and PJM boundary and unresolved project-specific details are preserved.',
 '2026-09-16T23:30:00Z','nexus_migration_124'),
('nexus_research_radar_texas_lane_001','TX','Texas','verified_seeded',
 'News confirms. Filings reveal. Permits whisper first.',
 'Public Utility Commission of Texas',ARRAY['ERCOT','MISO','SPP'],
 ARRAY['Oncor','CenterPoint Energy','AEP Texas','Texas-New Mexico Power','LCRA Transmission Services','Austin Energy','CPS Energy','Entergy Texas'],
 'Texas Commission on Environmental Quality',
 ARRAY['Dallas-Fort Worth','Collin County','Denton County','Williamson County','Travis County','Bexar County','Harris County','West Texas'],
 ARRAY['data center','large load','large flexible load','transmission','interconnection','curtailment','air permit','water'],
 '6aaac826-1d98-83e8-a239-8f8d70992db3',
 'Official ERCOT large-load integration, market-rule and notice records plus PUCT and TCEQ source portals were rechecked on 2026-09-16; automation remains disabled.',
 '2026-09-16T23:30:00Z','nexus_migration_124'),
('nexus_research_radar_michigan_lane_001','MI','Michigan','verified_seeded',
 'News confirms. Filings reveal. Permits whisper first.',
 'Michigan Public Service Commission',ARRAY['MISO','PJM'],
 ARRAY['Consumers Energy','DTE Electric','Indiana Michigan Power','Upper Michigan Energy Resources','Upper Peninsula Power'],
 'Michigan Department of Environment, Great Lakes, and Energy',
 ARRAY['Washtenaw County','Saline Township','Wixom','Wayne County','Oakland County','Kent County'],
 ARRAY['data center','large load','transmission','interconnection','Permit to Install','water use','cooling','ratepayer'],
 '6aaaac73-ffe0-83e8-bb05-7dd044f800e3',
 'Official MPSC case, tariff and affordability records plus EGLE permit portals were rechecked on 2026-09-16; the prototype lane is now seeded with review-gated records.',
 '2026-09-16T23:30:00Z','nexus_migration_124');

INSERT INTO nexus.research_radar_sources(
    research_radar_state_lane_id,source_code,source_name,source_type,authority_tier,
    source_base_uri,verification_status,verification_basis,limitations,verified_at,created_by
)
SELECT lane.research_radar_state_lane_id, seed.source_code, seed.source_name,
       seed.source_type, seed.authority_tier, seed.source_base_uri,
       'verified_official', seed.verification_basis, seed.limitations,
       '2026-09-16T23:30:00Z'::timestamptz, 'nexus_migration_124'
FROM (VALUES
('VA','va_scc_data_center_initiatives','Virginia SCC Data Center Initiatives','utility_regulator','A1','https://www.scc.virginia.gov/about-the-scc/scc-facts/','SCC page identifies current data-center tariff, cost-allocation, reliability and line-extension proceedings.','Summary page must be reconciled to the controlling orders and docket documents before any conclusion.'),
('VA','va_scc_docket_search','Virginia SCC DocketSearch','utility_regulator','A1','https://www.scc.virginia.gov/docketsearch','Official portal for Virginia State Corporation Commission case filings and orders.','Portal availability and document URLs may change; each filing still requires item-level review.'),
('VA','va_scc_transmission_projects','Virginia SCC Transmission Line Projects','utility_regulator','A1','https://www.scc.virginia.gov/consumers/public-utility/electricity-faqs/transmission-line-projects/','Official SCC index of transmission proceedings and regional case numbers.','Index descriptions do not replace applications, testimony, orders, or project-specific engineering evidence.'),
('VA','va_deq_air_public_notices','Virginia DEQ Air Public Notices','environmental_regulator','A2','https://www.deq.virginia.gov/news-info/shortcuts/public-notices/air','Official state portal for air-permit and public-notice records.','A permit notice establishes a proceeding, not completed construction, commercial operation, or ticker impact.'),
('VA','pjm_queue_scope','PJM Queue Scope','iso_rto','A3','https://queuescope.pjm.com/','Official PJM interconnection queue exploration source.','Queue presence does not establish completion probability, financing, energization, or investment impact.'),
('WI','wi_pscw_erf','Wisconsin PSC Electronic Records Filing','utility_regulator','A1','https://psc.wi.gov/Pages/NewsEvents/StayInformed.aspx','Official PSCW page routes users to docket documents in ERF and case information in CMS.','The navigation page is not the final order; controlling docket documents require separate review.'),
('WI','wi_pscw_6630_te_113','PSCW Docket 6630-TE-113 Decision Summary','utility_regulator','A1','https://psc.wi.gov/Documents/PressReleases/04.24.2026PressRelease.PDF','Official PSCW decision summary identifies the We Energies very-large-customer tariff docket.','The press summary states that the final order controls and should be reviewed in ERF.'),
('WI','wi_atc_137_ce_209','ATC Western Feed Transmission Line','transmission_owner','B1','https://www.atcllc.com/project/racine-county-western-feed/','Official transmission-owner project page identifies PSCW docket 137-CE-209 and approval status.','Project-owner statements require reconciliation to the PSCW order and updated construction filings.'),
('WI','wi_dnr_port_washington_eia','Wisconsin DNR Port Washington Environmental Review','environmental_regulator','A2','https://dnr.wisconsin.gov/topic/EIA/Portwashington.html','Official Wisconsin DNR page for the Port Washington project environmental review path.','Environmental review does not prove final permits, construction completion, load size, or investment impact.'),
('WI','miso_long_range_transmission','MISO Long Range Transmission Planning','iso_rto','A3','https://www.misoenergy.org/planning/long-range-transmission-planning/','Official MISO planning source for regional transmission development.','Regional plans require project-level linkage before attribution to a state site or public security.'),
('IN','in_iurc_portal','Indiana IURC Online Services Portal','utility_regulator','A1','https://iurc.portal.in.gov/','Official Indiana portal for docketed cases, filings and orders.','Search results and individual filings require item-level review; confidential material is not available.'),
('IN','in_idem_public_notices','Indiana IDEM Public Notices','environmental_regulator','A2','https://www.in.gov/idem/public-notices/public-notices-all-regions/','Official statewide environmental notice index for permits and hearings.','A notice is a procedural signal and does not prove final approval or construction.'),
('IN','in_fort_wayne_google_data_center','Fort Wayne Google Data Center','local_government','B1','https://engage.cityoffortwayne.org/data-center','Official city project information page for the Fort Wayne Google data-center development.','Local project information does not substitute for utility, transmission, environmental, or rate records.'),
('IN','miso_generator_interconnection','MISO Generator Interconnection','iso_rto','A3','https://www.misoenergy.org/planning/resource-utilization/generator-interconnection/','Official MISO interconnection planning source for most Indiana utility territories.','Generator queue data is not a direct large-load queue and should not be treated as project approval.'),
('TX','tx_puct_interchange','PUCT Interchange','utility_regulator','A1','https://interchange.puc.texas.gov/','Official Public Utility Commission of Texas docket and filing search portal.','Search results require review of the controlling filing or order; not every Texas utility is in ERCOT.'),
('TX','tx_ercot_large_load_integration','ERCOT Large Load Integration','iso_rto','A3','https://www.ercot.com/services/rq/large-load-integration','Official ERCOT large-load forms, process and implementation record.','Interconnection requests and process status do not prove energization, commercial viability, or attribution.'),
('TX','tx_ercot_pgrr144','ERCOT PGRR144','iso_rto','A3','https://www.ercot.com/mktrules/issues/PGRR144','Official ERCOT rule-change record for dynamic models of large computational loads.','Pending rule status can change after the verification timestamp and must be refreshed before use.'),
('TX','tx_ercot_market_notice_m_b091426_01','ERCOT Market Notice M-B091426-01','iso_rto','A3','https://www.ercot.com/services/comm/mkt_notices/M-B091426-01','Official ERCOT notice on data-center state, community and water-impact information requests.','The request for information is not a completed audit result or project approval decision.'),
('TX','tx_tceq_air_permits','TCEQ Air Permits','environmental_regulator','A2','https://www.tceq.texas.gov/permitting/air','Official Texas environmental permitting portal for air authorization and public participation.','Permit searches require facility-level identity resolution and do not independently prove a data-center link.'),
('MI','mi_mpsc_case_hearing','Michigan MPSC Case and Hearing Information','utility_regulator','A1','https://www.michigan.gov/mpsc/commission/case-hearing-info','Official MPSC gateway for orders, hearing notices, filings and e-dockets.','Gateway pages must be followed to the controlling order and complete docket record.'),
('MI','mi_mpsc_u_21859','MPSC Consumers Energy Large Load Terms','utility_regulator','A1','https://www.michigan.gov/mpsc/commission/news-releases/2025/11/06/mpsc-approves-terms-of-service-between-consumers-energy-and-data-centers','Official MPSC release summarizes the order in Case U-21859.','The release aids public understanding but does not replace the controlling Commission order.'),
('MI','mi_mpsc_u_21990','MPSC DTE Data Center Special Contracts','utility_regulator','A1','https://www.michigan.gov/mpsc/commission/events/2025/12/03/u-21990-dte-electric-special-contracts-public-hearing','Official MPSC hearing page identifies the U-21990 application and project parties.','The hearing page predates the final order and must be read with the later Commission decision.'),
('MI','mi_mpsc_affordability_letter_2026','MPSC July 2026 Affordability Letter','utility_regulator','A1','https://www.michigan.gov/mpsc/-/media/Project/Websites/mpsc/activity/07162026_MPSC_Affordability_Letter_to_Governor_Whitmer.pdf','Official MPSC letter addresses data-center cost allocation and transmission-cost recommendations.','Policy recommendations are not enacted law and must not be represented as binding tariff terms.'),
('MI','mi_egle_air_permits','Michigan EGLE Air Quality Permits','environmental_regulator','A2','https://www.michigan.gov/egle/about/organization/air-quality/air-permits','Official Michigan portal for air permits, Permit to Install and operating permit records.','Permit status must be confirmed at facility level; it does not independently establish project economics.')
) AS seed(state_code,source_code,source_name,source_type,authority_tier,source_base_uri,verification_basis,limitations)
JOIN nexus.research_radar_state_lanes lane USING(state_code);

INSERT INTO nexus.research_radar_scraper_definitions(
    research_radar_state_lane_id,scraper_code,scraper_name,source_types,
    classification_codes,execution_status,limitations,created_by
)
SELECT lane.research_radar_state_lane_id, seed.scraper_code, seed.scraper_name,
       seed.source_types, seed.classification_codes, 'defined_not_deployed',
       'Definition only. No schedule, fetcher, n8n workflow, network credential, automatic evidence admission, thesis promotion, brokerage action, or trade authority is installed by this migration.',
       'nexus_migration_124'
FROM (VALUES
('VA','va_scc_dominion_scraper_001','Virginia SCC large-load, tariff and transmission docket scraper',ARRAY['utility_regulator','iso_rto'],ARRAY['DATA_CENTER_LOAD','TRANSMISSION_UPGRADE','RATEPAYER_PRESSURE']),
('WI','wi_pscw_large_load_transmission_scraper_001','Wisconsin PSCW large-load and transmission docket scraper',ARRAY['utility_regulator','transmission_owner'],ARRAY['REGULATORY_RATE_LOAD_SIGNAL','GRID_CONSTRAINT_TRANSMISSION_SIGNAL']),
('WI','wi_dnr_air_water_scraper_002','Wisconsin DNR air, water and environmental notice scraper',ARRAY['environmental_regulator'],ARRAY['BACKUP_POWER_DIESEL_SIGNAL','WATER_COOLING_PERMIT_SIGNAL']),
('IN','in_iurc_large_load_dockets_scraper_001','Indiana IURC large-load and data-center docket scraper',ARRAY['utility_regulator','iso_rto'],ARRAY['UTILITY_LARGE_LOAD','SPECIAL_TARIFF_OR_CONTRACT','TRANSMISSION_UPGRADE']),
('TX','tx_puct_ercot_large_load_scraper_001','Texas PUCT and ERCOT large-load and transmission scraper',ARRAY['utility_regulator','iso_rto'],ARRAY['DATA_CENTER_LOAD','INTERCONNECTION_QUEUE','TRANSMISSION_UPGRADE']),
('TX','tx_tceq_air_water_scraper_002','Texas TCEQ air, water and diesel-permit scraper',ARRAY['environmental_regulator'],ARRAY['BACKUP_POWER_DIESEL','AIR_PERMIT_SIGNAL','WATER_COOLING_CONSTRAINT']),
('MI','mi_mpsc_large_load_scraper_001','Michigan MPSC large-load tariff and special-contract scraper',ARRAY['utility_regulator','environmental_regulator'],ARRAY['REGULATORY_RATE_LOAD_SIGNAL','DATA_CENTER_POWER_CONTRACT','RATEPAYER_COST_SHIFT'])
) AS seed(state_code,scraper_code,scraper_name,source_types,classification_codes)
JOIN nexus.research_radar_state_lanes lane USING(state_code);

INSERT INTO nexus.research_radar_signals(
    research_radar_state_lane_id,research_radar_source_id,signal_code,
    official_record_id,source_uri,source_title,source_published_at,retrieved_at,
    classification_code,evidence_tier,conviction_start,queue_status,
    factual_summary,interpretation_note,limitations,created_by
)
SELECT lane.research_radar_state_lane_id, source.research_radar_source_id,
       seed.signal_code,seed.official_record_id,seed.source_uri,seed.source_title,
       seed.source_published_at,'2026-09-16T23:30:00Z'::timestamptz,
       seed.classification_code,seed.evidence_tier,seed.conviction_start,
       'pending_human_review',seed.factual_summary,seed.interpretation_note,
       seed.limitations,'nexus_migration_124'
FROM (VALUES
('VA','va_scc_docket_search','va_pur_2026_00011','PUR-2026-00011','https://www.scc.virginia.gov/docketsearch/DOCS/8%40%23101%21.PDF','Dominion application for approval of large-load connection queue process standards','2026-02-10'::date,'DATA_CENTER_LOAD','A1','high','Dominion filed a Virginia SCC application for approval of large-load connection queue process standards after the Commission directed a separate proceeding in the 2025 biennial review.','The docket is an early official signal for data-center connection readiness, reliability and queue governance; it does not establish project-level completion or public-security value.','Application-stage evidence. Review the complete docket, testimony, procedural orders and final order before changing conviction.'),
('VA','va_scc_data_center_initiatives','va_pur_2026_00131','PUR-2026-00131','https://www.scc.virginia.gov/about-the-scc/scc-facts/','Dominion supplemental line-extension policy proceeding for large loads','2026-09-03'::date,'TRANSMISSION_COST_ALLOCATION','A1','high','The SCC states that the supplemental proceeding will address amendments intended to directly assign qualifying direct-connect transmission-facility costs to new or expanding large-load customers.','The proceeding is a strong ratepayer-protection and infrastructure-cost signal, but the final allocation mechanics remain subject to the docket record.','SCC summary page, not the full docket. Terms can change through testimony, settlement or final order.'),
('VA','va_scc_transmission_projects','va_pur_2026_00076','PUR-2026-00076','https://www.scc.virginia.gov/case-information/submit-public-comments/cases/pur-2026-00076.html','Northern Virginia 500 kV corridor optimization and related projects',NULL,'TRANSMISSION_UPGRADE','A1','high','The SCC lists a Dominion application involving 500 kV line rebuilds and additions in Loudoun County, a core Northern Virginia data-center and large-load zone.','The filing supports a transmission-buildout review lane; it does not by itself prove that data-center demand is the sole need or identify equipment-vendor awards.','Review the application, need study, route evidence, cost allocation and order before issuer or project attribution.'),
('WI','wi_pscw_6630_te_113','wi_6630_te_113','6630-TE-113','https://psc.wi.gov/Documents/PressReleases/04.24.2026PressRelease.PDF','We Energies Very Large Customer and Bespoke Resources Tariffs','2026-04-24'::date,'REGULATORY_RATE_LOAD_SIGNAL','A1','high','PSCW reported decisions in the We Energies very-large-customer tariff proceeding and identified the official docket for the controlling filings and final order.','This is a direct data-center cost-allocation and ratepayer-protection signal, but consumer and ticker implications require review of the final tariff and actual customer contracts.','The PSCW press summary explicitly says the final order controls; retrieve and review that order in ERF.'),
('WI','wi_atc_137_ce_209','wi_137_ce_209','137-CE-209','https://www.atcllc.com/project/racine-county-western-feed/','ATC Racine County Western Feed Transmission Line',NULL,'GRID_CONSTRAINT_TRANSMISSION_SIGNAL','B1','high','ATC states that PSCW approved the Western Feed project in May 2025 and that it includes two new double-circuit 345-kV lines serving the Mount Pleasant EITM zone.','The official project-owner page supports a Racine transmission-buildout watch, but vendor awards, final cost recovery and causal attribution require the PSCW docket.','Transmission-owner source. Reconcile stated scope, cost, schedule and need with PSCW docket 137-CE-209.'),
('WI','wi_dnr_port_washington_eia','wi_port_washington_lighthouse_eia','PORT-WASHINGTON-LIGHTHOUSE-EIA','https://dnr.wisconsin.gov/topic/EIA/Portwashington.html','Wisconsin DNR Port Washington environmental review record',NULL,'WATER_COOLING_PERMIT_SIGNAL','A2','high','Wisconsin DNR maintains an official environmental-review page for the Port Washington project, providing a state record path for water, sewer, stormwater, air and environmental issues.','The record is an early physical-buildout and permitting-constraint signal; it does not alone prove final approvals, operating load, construction completion or investment impact.','Environmental review page only. Confirm each permit, applicant identity, facility scope and final disposition separately.'),
('IN','in_iurc_portal','in_cause_46097','46097','https://iurc.portal.in.gov/_entity/sharepointdocumentlocation/2b48cf93-d9ee-ef11-be20-001dd80b8c52/bb9c6bba-fd52-45ad-8e64-a444aef13c39?file=ord_46097_021925.pdf','Indiana Michigan Power Industrial Power Tariff modifications','2025-02-19'::date,'SPECIAL_TARIFF_OR_CONTRACT','A1','high','The IURC order record for Cause 46097 addresses Indiana Michigan Power tariff modifications for large-load customers and identifies participation by Amazon, Google, Microsoft and the Data Center Coalition.','The cause is a primary large-load tariff and cost-protection signal for the PJM-served Indiana territory; project economics and public-security effects remain unproven.','Review the full order, tariff sheets, settlement, compliance reports and customer-specific filings before promotion.'),
('IN','in_iurc_portal','in_cause_46022_large_load_rfp','46022-2024-10-15','https://iurc.portal.in.gov/_entity/sharepointdocumentlocation/aeda3f2a-c08b-ef11-ac21-001dd808c9d7/bb9c6bba-fd52-45ad-8e64-a444aef13c39?file=46022_AESIN_AES+Indiana+Response+in+Opposition+to+Petition+to+Re-Open+Record_101524.pdf','AES Indiana response discussing large-load resource solicitation','2024-10-15'::date,'UTILITY_LARGE_LOAD','A1','medium','AES Indiana told the IURC that its resource solicitation was intended to assess potential transmission-level resources for rapid large-load opportunities while stating that no executed data-center construction service agreement existed at that time.','The filing is evidence of utility planning for prospective large load and also a caution against treating pipeline interest as a committed project.','Dated 2024 filing in a repowering cause. Refresh later AES filings and do not infer a current customer commitment.'),
('TX','tx_ercot_large_load_integration','tx_ercot_monthly_feb_2026','ERCOT-MONTHLY-FEB-2026','https://www.ercot.com/files/docs/2026/03/17/ERCOT-Monthly-February-2026-FINAL.pdf','ERCOT Monthly February 2026 large-load batch update','2026-03-17'::date,'INTERCONNECTION_QUEUE','A3','high','ERCOT reported more than 232,000 MW in the large-load interconnection process through 2030 and identified data centers as the dominant project type in that request set.','The magnitude is a strong system-planning signal, not a forecast that all requested load will energize; queue attrition and duplication must be expected.','Aggregate request data. It does not identify individual projects, completion probabilities, financing or ticker exposure.'),
('TX','tx_ercot_pgrr144','tx_ercot_pgrr144_2026_09_15','PGRR144','https://www.ercot.com/mktrules/issues/PGRR144','Dynamic model requirements for large computational loads','2026-09-15'::date,'LARGE_LOAD_RELIABILITY_RULE','A3','high','ERCOT records that its Board recommended PGRR144 for approval on September 15, 2026, with the issue pending PUCT consideration at the verification time.','The rule record signals increasing modeling and reliability requirements for large electronic loads; it is not yet evidence of a final PUCT decision.','Status is time-sensitive. Refresh the ERCOT issue page and PUCT action before relying on the pending label.'),
('TX','tx_ercot_market_notice_m_b091426_01','tx_ercot_m_b091426_01','M-B091426-01','https://www.ercot.com/services/comm/mkt_notices/M-B091426-01','Data-center state, community and water-impact information request','2026-09-14'::date,'WATER_COOLING_CONSTRAINT','A3','high','ERCOT issued an information request for data centers of at least 25 MW and described coordination with the PUCT and Texas Water Development Board on water sources and consumption.','The notice elevates water and community impact to an official interconnection-review signal, but the audit conclusions were not yet published.','Request-for-information stage only. Do not treat requested disclosures as findings or project approvals.'),
('MI','mi_mpsc_u_21859','mi_u_21859','U-21859','https://www.michigan.gov/mpsc/commission/news-releases/2025/11/06/mpsc-approves-terms-of-service-between-consumers-energy-and-data-centers','Consumers Energy terms for data centers and very large customers','2025-11-06'::date,'REGULATORY_RATE_LOAD_SIGNAL','A1','high','MPSC approved large-load terms including a 15-year minimum contract, 80 percent minimum billing demand, exit protections, collateral and customer-specific filings intended to prevent cost shifting.','The order is a strong Michigan ratepayer-protection and data-center tariff signal; it does not identify approved portfolio action or guarantee projected load.','Official summary of one utility tariff. Review the controlling U-21859 order and later compliance cases.'),
('MI','mi_mpsc_u_21990','mi_u_21990','U-21990','https://www.michigan.gov/mpsc/commission/events/2025/12/03/u-21990-dte-electric-special-contracts-public-hearing','DTE special contracts for Washtenaw County data center','2025-12-03'::date,'DATA_CENTER_POWER_CONTRACT','A1','high','The MPSC hearing record identifies DTE special-contract applications with Green Chile Ventures for a proposed Washtenaw County data center and related energy-storage arrangements.','The case is a direct large-load power-contract signal and requires review of the later conditional approval, cost protections, storage obligations and execution conditions.','The seeded URI is the hearing record, not the final order. Review the complete U-21990 docket before promotion.'),
('MI','mi_mpsc_affordability_letter_2026','mi_mpsc_affordability_letter_2026','MPSC-AFFORDABILITY-LETTER-2026-07-16','https://www.michigan.gov/mpsc/-/media/Project/Websites/mpsc/activity/07162026_MPSC_Affordability_Letter_to_Governor_Whitmer.pdf','MPSC affordability and responsible growth recommendations','2026-07-16'::date,'RATEPAYER_COST_SHIFT','A1','high','MPSC recommended codifying requirements that data centers pay the full costs they impose, including transmission upgrades, and discussed evolving cost-allocation protections.','The letter is an authoritative policy signal for ratepayer pressure and transmission allocation, but its recommendations are not enacted law.','Recommendation document. Verify legislation, tariffs and case orders separately before treating any proposal as binding.')
) AS seed(state_code,source_code,signal_code,official_record_id,source_uri,source_title,source_published_at,classification_code,evidence_tier,conviction_start,factual_summary,interpretation_note,limitations)
JOIN nexus.research_radar_state_lanes lane USING(state_code)
JOIN nexus.research_radar_sources source
  ON source.research_radar_state_lane_id=lane.research_radar_state_lane_id
 AND source.source_code=seed.source_code;

INSERT INTO nexus.research_radar_ticker_links(
    research_radar_signal_id,ticker,relationship_code,link_basis,created_by
)
SELECT signal.research_radar_signal_id, seed.ticker, seed.relationship_code,
       'Research-only candidate mapping from the state-lane doctrine. The official record does not prove issuer revenue, contract award, valuation support, position sizing, thesis approval, or a trading action.',
       'nexus_migration_124'
FROM (VALUES
('va_pur_2026_00011','PWR','transmission_grid_watch'),('va_pur_2026_00011','ETN','electrical_equipment_watch'),('va_pur_2026_00011','VRT','data_center_infrastructure_watch'),
('va_pur_2026_00131','PWR','transmission_grid_watch'),('va_pur_2026_00131','GEV','transmission_grid_watch'),('va_pur_2026_00131','ETN','electrical_equipment_watch'),
('va_pur_2026_00076','PWR','transmission_grid_watch'),('va_pur_2026_00076','GEV','transmission_grid_watch'),('va_pur_2026_00076','POWL','electrical_equipment_watch'),
('wi_6630_te_113','XLP','consumer_stress_watch'),('wi_6630_te_113','WMT','consumer_stress_watch'),('wi_6630_te_113','DLTR','consumer_stress_watch'),
('wi_137_ce_209','PWR','transmission_grid_watch'),('wi_137_ce_209','GEV','transmission_grid_watch'),('wi_137_ce_209','ETN','electrical_equipment_watch'),
('wi_port_washington_lighthouse_eia','VRT','data_center_infrastructure_watch'),('wi_port_washington_lighthouse_eia','CAT','backup_power_watch'),('wi_port_washington_lighthouse_eia','CMI','backup_power_watch'),
('in_cause_46097','PWR','transmission_grid_watch'),('in_cause_46097','ETN','electrical_equipment_watch'),('in_cause_46097','VRT','data_center_infrastructure_watch'),
('in_cause_46022_large_load_rfp','GEV','transmission_grid_watch'),('in_cause_46022_large_load_rfp','ETN','electrical_equipment_watch'),('in_cause_46022_large_load_rfp','VRT','data_center_infrastructure_watch'),
('tx_ercot_monthly_feb_2026','PWR','transmission_grid_watch'),('tx_ercot_monthly_feb_2026','GEV','transmission_grid_watch'),('tx_ercot_monthly_feb_2026','ETN','electrical_equipment_watch'),('tx_ercot_monthly_feb_2026','VRT','data_center_infrastructure_watch'),
('tx_ercot_pgrr144_2026_09_15','ETN','electrical_equipment_watch'),('tx_ercot_pgrr144_2026_09_15','VRT','data_center_infrastructure_watch'),
('tx_ercot_m_b091426_01','VRT','data_center_infrastructure_watch'),('tx_ercot_m_b091426_01','CAT','backup_power_watch'),('tx_ercot_m_b091426_01','CMI','backup_power_watch'),
('mi_u_21859','XLP','consumer_stress_watch'),('mi_u_21859','WMT','consumer_stress_watch'),('mi_u_21859','DLTR','consumer_stress_watch'),
('mi_u_21990','PWR','transmission_grid_watch'),('mi_u_21990','ETN','electrical_equipment_watch'),('mi_u_21990','VRT','data_center_infrastructure_watch'),
('mi_mpsc_affordability_letter_2026','XLP','consumer_stress_watch'),('mi_mpsc_affordability_letter_2026','WMT','consumer_stress_watch'),('mi_mpsc_affordability_letter_2026','DLTR','consumer_stress_watch')
) AS seed(signal_code,ticker,relationship_code)
JOIN nexus.research_radar_signals signal USING(signal_code);

CREATE VIEW nexus.v_research_radar_review_queue AS
SELECT lane.state_code,lane.state_name,lane.lane_code,
       signal.research_radar_signal_id,signal.signal_code,signal.official_record_id,
       signal.source_title,signal.source_uri,signal.source_published_at,
       signal.retrieved_at,signal.classification_code,signal.evidence_tier,
       signal.conviction_start,signal.queue_status,signal.factual_summary,
       signal.interpretation_note,signal.limitations,
       source.source_code,source.source_name,source.source_type,
       coalesce(array_agg(DISTINCT link.ticker ORDER BY link.ticker)
                FILTER (WHERE link.ticker IS NOT NULL),ARRAY[]::text[]) AS candidate_tickers,
       signal.thesis_promotion_allowed,signal.trade_action_allowed
FROM nexus.research_radar_signals signal
JOIN nexus.research_radar_state_lanes lane USING(research_radar_state_lane_id)
JOIN nexus.research_radar_sources source USING(research_radar_source_id)
LEFT JOIN nexus.research_radar_ticker_links link USING(research_radar_signal_id)
GROUP BY lane.state_code,lane.state_name,lane.lane_code,
         signal.research_radar_signal_id,signal.signal_code,signal.official_record_id,
         signal.source_title,signal.source_uri,signal.source_published_at,
         signal.retrieved_at,signal.classification_code,signal.evidence_tier,
         signal.conviction_start,signal.queue_status,signal.factual_summary,
         signal.interpretation_note,signal.limitations,source.source_code,
         source.source_name,source.source_type,signal.thesis_promotion_allowed,
         signal.trade_action_allowed;

CREATE VIEW nexus.v_research_radar_state_status AS
SELECT lane.research_radar_state_lane_id,lane.state_code,lane.state_name,lane.lane_code,
       lane.lane_status,lane.verified_at,
       count(DISTINCT source.research_radar_source_id) AS verified_source_count,
       count(DISTINCT signal.research_radar_signal_id) AS pending_signal_count,
       count(DISTINCT link.research_radar_ticker_link_id) AS candidate_ticker_link_count,
       count(DISTINCT scraper.research_radar_scraper_definition_id) AS defined_scraper_count,
       bool_and(NOT coalesce(scraper.execution_enabled,false)) AS scraper_execution_disabled,
       bool_and(NOT signal.thesis_promotion_allowed) AS thesis_promotion_blocked,
       bool_and(NOT signal.trade_action_allowed) AS trade_action_blocked
FROM nexus.research_radar_state_lanes lane
LEFT JOIN nexus.research_radar_sources source USING(research_radar_state_lane_id)
LEFT JOIN nexus.research_radar_signals signal USING(research_radar_state_lane_id)
LEFT JOIN nexus.research_radar_ticker_links link USING(research_radar_signal_id)
LEFT JOIN nexus.research_radar_scraper_definitions scraper USING(research_radar_state_lane_id)
GROUP BY lane.research_radar_state_lane_id,lane.state_code,lane.state_name,
         lane.lane_code,lane.lane_status,lane.verified_at;

CREATE VIEW nexus.v_research_radar_governance_health AS
SELECT
    (SELECT count(*) FROM nexus.research_radar_state_lanes) AS state_lane_count,
    (SELECT count(*) FROM nexus.research_radar_sources) AS source_count,
    (SELECT count(*) FROM nexus.research_radar_signals) AS pending_signal_count,
    (SELECT count(*) FROM nexus.research_radar_ticker_links) AS candidate_ticker_link_count,
    (SELECT count(*) FROM nexus.research_radar_scraper_definitions) AS scraper_definition_count,
    (SELECT count(*) FROM nexus.research_radar_state_lanes
      WHERE NOT human_review_required OR thesis_promotion_allowed OR trade_action_allowed) AS lane_control_violation_count,
    (SELECT count(*) FROM nexus.research_radar_sources
      WHERE automated_intake_enabled OR verification_status <> 'verified_official') AS source_control_violation_count,
    (SELECT count(*) FROM nexus.research_radar_signals
      WHERE queue_status <> 'pending_human_review' OR thesis_promotion_allowed OR trade_action_allowed) AS signal_control_violation_count,
    (SELECT count(*) FROM nexus.research_radar_scraper_definitions
      WHERE execution_enabled OR NOT human_review_required OR trade_action_allowed) AS scraper_control_violation_count,
    (SELECT count(*) FROM nexus.research_radar_ticker_links
      WHERE NOT human_review_required OR thesis_promotion_allowed OR trade_action_allowed) AS ticker_link_control_violation_count;

REVOKE ALL ON nexus.research_radar_state_lanes,nexus.research_radar_sources,
    nexus.research_radar_scraper_definitions,nexus.research_radar_signals,
    nexus.research_radar_ticker_links FROM PUBLIC;
GRANT SELECT ON nexus.v_research_radar_review_queue,
    nexus.v_research_radar_state_status,nexus.v_research_radar_governance_health
    TO nexus_automation_reader,nexus_automation_intake,nexus_human_reviewer;

COMMENT ON TABLE nexus.research_radar_state_lanes IS
    'Immutable verified configuration for state-specific official-record Research Radar lanes. Every lane is human-review gated and carries no thesis-promotion or trading authority.';
COMMENT ON TABLE nexus.research_radar_sources IS
    'Verified official source map for Research Radar. A row does not enroll the source in the automation allowlist and automated intake remains disabled.';
COMMENT ON TABLE nexus.research_radar_scraper_definitions IS
    'Non-executing scraper definitions recovered from the state chats. No workflow, schedule, network action or credential is installed.';
COMMENT ON TABLE nexus.research_radar_signals IS
    'Official-record candidates queued for human review. These are not admitted evidence, approved theses, position instructions or trade signals.';
COMMENT ON TABLE nexus.research_radar_ticker_links IS
    'Research-only candidate mappings. A link does not prove issuer exposure, portfolio fit, valuation support, sizing or trade approval.';
COMMENT ON VIEW nexus.v_research_radar_review_queue IS
    'Human-review queue for the five seeded state lanes with official record identity, limitations and candidate ticker mappings.';
COMMENT ON VIEW nexus.v_research_radar_state_status IS
    'Per-state completion and control status for verified sources, pending signals, disabled scraper definitions and blocked action flags.';
COMMENT ON VIEW nexus.v_research_radar_governance_health IS
    'Aggregate Research Radar counts and fail-closed control violation counts; every violation count must remain zero.';

COMMIT;
