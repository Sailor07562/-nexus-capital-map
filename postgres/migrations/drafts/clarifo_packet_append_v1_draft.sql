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
  p_adapter_version text default 'clarifo_nexus_adapter_v2',
  p_market text default null,
  p_cik text default null,
  p_retrieved_at timestamptz default clock_timestamp()
)
returns table (outcome text, clarifo_ingestion_packet_id uuid)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_id uuid;
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

  insert into nexus.clarifo_ingestion_packets as packet (
    packet_key, adapter_version, ticker, company_name, instrument_type,
    research_lane, market, cik, packet_json, evidence_status, review_status,
    thesis_promotion_allowed, trade_action_allowed, retrieved_at, created_by
  ) values (
    p_packet_key, p_adapter_version, p_ticker, p_company_name, p_instrument_type,
    p_research_lane, p_market, p_cik, p_packet_json, 'evidence_open',
    'pending_human_review', false, false, coalesce(p_retrieved_at, clock_timestamp()),
    'clarifo_nexus_adapter_v2'
  )
  on conflict (packet_key) do nothing
  returning packet.clarifo_ingestion_packet_id into v_id;

  if v_id is not null then
    return query select 'inserted'::text, v_id;
    return;
  end if;

  select p.clarifo_ingestion_packet_id
    into v_id
    from nexus.clarifo_ingestion_packets as p
    where p.packet_key = p_packet_key;

  return query select 'duplicate'::text, v_id;
end;
$function$;

revoke all on function nexus.clarifo_packet_append_v1(
  text, text, text, text, text, jsonb, text, text, text, timestamptz
) from public, anon, authenticated;

grant execute on function nexus.clarifo_packet_append_v1(
  text, text, text, text, text, jsonb, text, text, text, timestamptz
) to service_role;
