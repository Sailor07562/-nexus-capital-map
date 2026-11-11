-- DRAFT ONLY. Review and reconcile with canonical migration lineage before applying.
-- Narrow append primitive for Clarifo packets. This does not promote evidence,
-- supersede prior packets, or grant table-level INSERT to the API role.

create or replace function nexus.clarifo_packet_append_v1(
  p_packet_key text,
  p_ticker text,
  p_company_name text,
  p_instrument_type text,
  p_research_lane text,
  p_packet_json jsonb,
  p_adapter_version text,
  p_market text,
  p_cik text
)
returns table (outcome text, clarifo_ingestion_packet_id uuid, stored_content_hash text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id uuid;
  v_hash text;
  v_expected_hash text;
  v_ticker text;
  v_company_name text;
  v_instrument_type text;
  v_research_lane text;
  v_market text;
  v_cik text;
  v_packet_json jsonb;
  v_adapter_version text;
begin
  if p_packet_key is null or length(btrim(p_packet_key)) = 0 or length(p_packet_key) > 240 then
    raise exception 'invalid packet_key' using errcode = '22023';
  end if;
  if p_ticker is null or p_ticker !~ '^[A-Z0-9.]{1,15}$' then
    raise exception 'invalid ticker' using errcode = '22023';
  end if;
  if p_company_name is null or length(btrim(p_company_name)) = 0
     or p_instrument_type is null or length(btrim(p_instrument_type)) = 0
     or p_research_lane is null or length(btrim(p_research_lane)) = 0 then
    raise exception 'required packet metadata missing' using errcode = '22023';
  end if;
  if p_packet_json is null or jsonb_typeof(p_packet_json) <> 'object' then
    raise exception 'packet_json must be a JSON object' using errcode = '22023';
  end if;
  if p_adapter_version is distinct from 'clarifo_nexus_adapter_v2' then
    raise exception 'unsupported adapter version' using errcode = '22023';
  end if;
  -- Hash binds all caller-controlled metadata and the complete JSONB packet.
  v_expected_hash := encode(extensions.digest(convert_to(jsonb_build_object(
       'packet_key', p_packet_key, 'adapter_version', p_adapter_version,
       'ticker', p_ticker, 'company_name', p_company_name,
       'instrument_type', p_instrument_type, 'research_lane', p_research_lane,
       'market', p_market, 'cik', p_cik, 'packet_json', p_packet_json
     )::text, 'UTF8'), 'sha256'), 'hex');

  insert into nexus.clarifo_ingestion_packets as packet (
    packet_key, adapter_version, ticker, company_name, instrument_type,
    research_lane, market, cik, packet_json, content_hash, evidence_status, review_status,
    thesis_promotion_allowed, trade_action_allowed, created_by
  ) values (
    p_packet_key, p_adapter_version, p_ticker, p_company_name, p_instrument_type,
    p_research_lane, p_market, p_cik, p_packet_json, v_expected_hash, 'evidence_open',
    'pending_human_review', false, false, 'clarifo_nexus_adapter_v2'
  )
  on conflict (packet_key) do nothing
  returning packet.clarifo_ingestion_packet_id into v_id;

  if v_id is not null then
    return query select 'inserted'::text, v_id, v_expected_hash;
    return;
  end if;

  select p.clarifo_ingestion_packet_id, p.content_hash, p.ticker, p.company_name,
         p.instrument_type, p.research_lane, p.market, p.cik, p.packet_json, p.adapter_version
    into v_id, v_hash, v_ticker, v_company_name, v_instrument_type,
         v_research_lane, v_market, v_cik, v_packet_json, v_adapter_version
    from nexus.clarifo_ingestion_packets as p
    where p.packet_key = p_packet_key
    for update;

  if v_id is null or v_hash is null then
    raise exception 'duplicate packet could not be reconciled' using errcode = 'P0002';
  end if;
  if v_hash is distinct from v_expected_hash
     or v_ticker is distinct from p_ticker
     or v_company_name is distinct from p_company_name
     or v_instrument_type is distinct from p_instrument_type
     or v_research_lane is distinct from p_research_lane
     or v_market is distinct from p_market
     or v_cik is distinct from p_cik
     or v_packet_json is distinct from p_packet_json
     or v_adapter_version is distinct from p_adapter_version then
    return query select 'conflict'::text, v_id, v_hash;
    return;
  end if;

  return query select 'identical'::text, v_id, v_hash;
end;
$function$;

revoke all on function nexus.clarifo_packet_append_v1(
  text, text, text, text, text, jsonb, text, text, text
) from public, anon, authenticated;

grant execute on function nexus.clarifo_packet_append_v1(
  text, text, text, text, text, jsonb, text, text, text
) to service_role;
