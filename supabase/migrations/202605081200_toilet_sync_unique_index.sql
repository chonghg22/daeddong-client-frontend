begin;

create unique index if not exists toilet_external_source_external_id_key
  on daeddong."TOILET" (external_source, external_id)
  where external_source is not null and external_id is not null;

commit;
