import postgres from "npm:postgres@3.4.7";

type RawApiItem = Record<string, unknown>;

type NormalizedToilet = {
  external_source: string;
  external_id: string;
  name: string | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  si: string | null;
  gungu: string | null;
  open_time: string | null;
  close_time: string | null;
  toilet_type: string | null;
  count_man: number | null;
  count_women: number | null;
  baby_yn: string | null;
  unusual_yn: string | null;
  cctv_yn: string | null;
  alarm_yn: string | null;
  pwd_yn: string | null;
  open_yn: string | null;
  etc: string | null;
  source_updated_at: string | null;
  last_synced_at: string;
  is_active: boolean;
};

type ExistingToiletRow = {
  seq: number | null;
  external_source: string | null;
  external_id: string | null;
  name: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  is_active: boolean | null;
};

const source = Deno.env.get("TOILET_SOURCE_NAME") ?? "public_toilet_api";
const apiBaseUrl =
  Deno.env.get("TOILET_API_BASE_URL") ??
  "https://apis.data.go.kr/1741000/public_restroom_info";
const apiServiceKey = Deno.env.get("TOILET_API_SERVICE_KEY") ?? "";
const apiMode = Deno.env.get("TOILET_API_MODE") ?? "info";
const syncFrom = Deno.env.get("TOILET_SYNC_FROM");
const syncTo = Deno.env.get("TOILET_SYNC_TO");
const historyBaseDate = Deno.env.get("TOILET_HISTORY_BASE_DATE");
const regionCodes = (Deno.env.get("TOILET_REGION_CODES") ?? "")
  .split(",")
  .map((code) => code.trim())
  .filter((code) => code.length > 0);
const targetSchema = Deno.env.get("TOILET_TARGET_SCHEMA") ?? "daeddong";
const targetTable = Deno.env.get("TOILET_TARGET_TABLE") ?? "TOILET";
const dbUrl = Deno.env.get("SUPABASE_DB_URL") ?? "";

if (!dbUrl) {
  throw new Error("SUPABASE_DB_URL is not configured");
}

const sql = postgres(dbUrl, {
  prepare: false,
  max: 1,
});

const quotedTargetTable = `"${targetSchema}"."${targetTable}"`;
const quotedRunsTable = `"${targetSchema}"."toilet_import_runs"`;
const quotedRawTable = `"${targetSchema}"."toilet_import_raw"`;
const quotedHistoryTable = `"${targetSchema}"."toilet_change_history"`;

function formatError(error: unknown): Record<string, unknown> {
  if (error instanceof Error) {
    return {
      name: error.name,
      message: error.message,
      stack: error.stack,
    };
  }

  if (typeof error === "object" && error !== null) {
    return { ...(error as Record<string, unknown>) };
  }

  return { message: String(error) };
}

function asString(value: unknown): string | null {
  if (value == null) return null;
  const text = String(value).trim();
  return text.length == 0 ? null : text;
}

function asNumber(value: unknown): number | null {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseOpenClose(opnHr: string | null, opnHrDtl: string | null): {
  openTime: string | null;
  closeTime: string | null;
  openYn: string | null;
} {
  if (opnHr == "상시") {
    return { openTime: "00:00", closeTime: "24:00", openYn: "Y" };
  }

  if (opnHrDtl != null && opnHrDtl.includes("~")) {
    const parts = opnHrDtl.split("~").map((part) => part.trim());
    if (parts.length == 2) {
      return {
        openTime: parts[0] || null,
        closeTime: parts[1] || null,
        openYn: null,
      };
    }
  }

  return {
    openTime: opnHr,
    closeTime: opnHrDtl,
    openYn: null,
  };
}

function extractItems(body: unknown): RawApiItem[] {
  if (typeof body !== "object" || body === null) return [];
  const record = body as Record<string, unknown>;
  const response = record.response;
  if (typeof response !== "object" || response === null) return [];
  const responseRecord = response as Record<string, unknown>;
  const bodyValue = responseRecord.body;
  if (typeof bodyValue !== "object" || bodyValue === null) return [];
  const bodyRecord = bodyValue as Record<string, unknown>;
  const items = bodyRecord.items;
  if (typeof items !== "object" || items === null) return [];
  const itemsRecord = items as Record<string, unknown>;
  const itemValue = itemsRecord.item;
  if (Array.isArray(itemValue)) {
    return itemValue.filter((item): item is RawApiItem =>
      typeof item === "object" && item !== null
    );
  }
  if (typeof itemValue === "object" && itemValue !== null) {
    return [itemValue as RawApiItem];
  }
  return [];
}

function extractTotalCount(body: unknown): number | null {
  if (typeof body !== "object" || body === null) return null;
  const record = body as Record<string, unknown>;
  const response = record.response;
  if (typeof response !== "object" || response === null) return null;
  const responseRecord = response as Record<string, unknown>;
  const bodyValue = responseRecord.body;
  if (typeof bodyValue !== "object" || bodyValue === null) return null;
  const bodyRecord = bodyValue as Record<string, unknown>;
  const totalCount = bodyRecord.totalCount;
  if (typeof totalCount === "number") return totalCount;
  if (typeof totalCount === "string") {
    const parsed = Number(totalCount);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function isInactiveStatus(item: RawApiItem): boolean {
  const statusCode =
    asString(item.biz_stt_cd) ??
    asString(item.BIZ_STT_CD) ??
    asString(item.bss_stt_cd) ??
    asString(item.BSS_STT_CD);
  const statusName =
    asString(item.biz_stt_nm) ??
    asString(item.BIZ_STT_NM);
  const updateType =
    asString(item.dat_updt_se) ??
    asString(item.DAT_UPDT_SE);

  const inactiveCodes = new Set(["03", "04", "05"]);
  const inactiveNames = ["폐업", "취소", "말소", "만료", "정지", "중지", "삭제", "전출"];

  if (statusCode != null && inactiveCodes.has(statusCode)) return true;
  if (statusName != null && inactiveNames.some((name) => statusName.includes(name))) {
    return true;
  }
  if (updateType != null && ["D", "DELETE", "DEL"].includes(updateType.toUpperCase())) {
    return true;
  }
  return false;
}

function normalizeItem(item: RawApiItem): NormalizedToilet | null {
  const countMan =
    asNumber(item.MALE_TOILT_CNT) ??
    asNumber(item.male_toilt_cnt);
  const countWomen =
    asNumber(item.FEMALE_TOILT_CNT) ??
    asNumber(item.female_toilt_cnt);
  const maleDisabledCount = asNumber(item.MALE_FRDBL_TOILT_CNT) ?? 0;
  const femaleDisabledCount = asNumber(item.FEMALE_FRDBL_TOILT_CNT) ?? 0;
  const opnHr = asString(item.OPN_HR) ?? asString(item.opn_hr);
  const opnHrDtl = asString(item.OPN_HR_DTL) ?? asString(item.opn_hr_dtl);
  const openInfo = parseOpenClose(opnHr, opnHrDtl);
  const inactive = isInactiveStatus(item);
  const externalId = asString(item.MNG_NO) ?? asString(item.mng_no);

  if (externalId == null) return null;

  return {
    external_source: source,
    external_id: externalId,
    name: asString(item.RSTRM_NM) ?? asString(item.rstrm_nm),
    latitude: asNumber(item.WGS84_LAT) ?? asNumber(item.wgs84_lat),
    longitude: asNumber(item.WGS84_LOT) ?? asNumber(item.wgs84_lot),
    address:
      asString(item.LCTN_ROAD_NM_ADDR) ??
      asString(item.LCTN_LOTNO_ADDR) ??
      asString(item.lctn_road_nm_addr) ??
      asString(item.lctn_lotno_addr),
    si: null,
    gungu: null,
    open_time: openInfo.openTime,
    close_time: openInfo.closeTime,
    toilet_type: asString(item.SE_NM) ?? asString(item.se_nm),
    count_man: countMan == null ? null : Math.trunc(countMan),
    count_women: countWomen == null ? null : Math.trunc(countWomen),
    baby_yn: asString(item.DIAP_EXCHCON_EN) ?? asString(item.diap_exchcon_en),
    unusual_yn: maleDisabledCount > 0 || femaleDisabledCount > 0 ? "Y" : "N",
    cctv_yn:
      asString(item.RSTRM_ENTRAN_CCTV_INSTL_EN) ??
      asString(item.rstrm_entran_cctv_instl_en),
    alarm_yn:
      asString(item.EMRGNCBLL_INSTL_YN) ??
      asString(item.emrgncbll_instl_yn),
    pwd_yn: null,
    open_yn: openInfo.openYn,
    etc: asString(item.MNG_INST_NM) ?? asString(item.mng_inst_nm),
    source_updated_at:
      asString(item.DAT_UPDT_PNT) ??
      asString(item.LAST_MDFCN_PNT),
    last_synced_at: new Date().toISOString(),
    is_active: !inactive,
  };
}

async function fetchAllPages(): Promise<RawApiItem[]> {
  const items: RawApiItem[] = [];
  const targets = regionCodes.length > 0 ? regionCodes : [null];

  for (const regionCode of targets) {
    let page = 1;
    while (true) {
      const url = new URL(`${apiBaseUrl}/${apiMode}`);
      url.searchParams.set("serviceKey", apiServiceKey);
      url.searchParams.set("pageNo", String(page));
      url.searchParams.set("numOfRows", "100");
      url.searchParams.set("returnType", "json");

      if (regionCode != null) {
        url.searchParams.set("cond[OPN_ATMY_GRP_CD::EQ]", regionCode);
      }
      if (apiMode === "info") {
        if (syncFrom) url.searchParams.set("cond[DAT_UPDT_PNT::GTE]", syncFrom);
        if (syncTo) url.searchParams.set("cond[DAT_UPDT_PNT::LT]", syncTo);
      }
      if (apiMode === "history") {
        if (!historyBaseDate) {
          throw new Error("TOILET_HISTORY_BASE_DATE is required for history mode");
        }
        url.searchParams.set("cond[BASE_DATE::EQ]", historyBaseDate);
        if (syncFrom) url.searchParams.set("cond[LAST_MDFCN_PNT::GTE]", syncFrom);
        if (syncTo) url.searchParams.set("cond[LAST_MDFCN_PNT::LT]", syncTo);
      }

      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`External API request failed: ${response.status}`);
      }

      const body = await response.json();
      const pageItems = extractItems(body);
      const totalCount = extractTotalCount(body);
      if (pageItems.length === 0) break;
      items.push(...pageItems);
      const hasNext = (totalCount != null && page * 100 < totalCount) || pageItems.length === 100;
      if (!hasNext) break;
      page += 1;
    }
  }

  return items;
}

async function insertRun(): Promise<number> {
  const rows = await sql.unsafe(
    `insert into ${quotedRunsTable} (source, status) values ($1, 'running') returning id`,
    [source],
  );
  return rows[0].id as number;
}

async function updateRun(runId: number, patch: Record<string, unknown>) {
  const fields = Object.keys(patch);
  if (fields.length === 0) return;
  const assignments = fields.map((field, index) => `"${field}" = $${index + 2}`).join(", ");
  const values = [runId, ...fields.map((field) => patch[field])];
  await sql.unsafe(
    `update ${quotedRunsTable} set ${assignments} where id = $1`,
    values,
  );
}

Deno.serve(async () => {
  let runId: number | null = null;

  try {
    runId = await insertRun();

    const rawItems = await fetchAllPages();
    const normalizedPairs = rawItems
      .map((payload) => ({ payload, normalized: normalizeItem(payload) }))
      .filter((pair): pair is { payload: RawApiItem; normalized: NormalizedToilet } =>
        pair.normalized !== null
      );
    const normalizedItems = normalizedPairs.map((pair) => pair.normalized);

    const currentRows = await sql.unsafe(
      `select seq, external_source, external_id, name, address, latitude, longitude, is_active
       from ${quotedTargetTable}
       where external_source = $1`,
      [source],
    ) as ExistingToiletRow[];

    const currentByKey = new Map(
      currentRows.map((row) => [`${row.external_source}::${row.external_id}`, row]),
    );

    const seenKeys = new Set<string>();

    for (const item of normalizedItems) {
      seenKeys.add(`${item.external_source}::${item.external_id}`);
      await sql.unsafe(
        `insert into ${quotedTargetTable}
         (external_source, external_id, name, latitude, longitude, address, si, gungu, open_time, close_time, toilet_type, count_man, count_women, baby_yn, unusual_yn, cctv_yn, alarm_yn, pwd_yn, open_yn, etc, source_updated_at, last_synced_at, is_active)
         values
         ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23)
         on conflict (external_source, external_id) do update set
           name = excluded.name,
           latitude = excluded.latitude,
           longitude = excluded.longitude,
           address = excluded.address,
           si = excluded.si,
           gungu = excluded.gungu,
           open_time = excluded.open_time,
           close_time = excluded.close_time,
           toilet_type = excluded.toilet_type,
           count_man = excluded.count_man,
           count_women = excluded.count_women,
           baby_yn = excluded.baby_yn,
           unusual_yn = excluded.unusual_yn,
           cctv_yn = excluded.cctv_yn,
           alarm_yn = excluded.alarm_yn,
           pwd_yn = excluded.pwd_yn,
           open_yn = excluded.open_yn,
           etc = excluded.etc,
           source_updated_at = excluded.source_updated_at,
           last_synced_at = excluded.last_synced_at,
           is_active = excluded.is_active`,
        [
          item.external_source,
          item.external_id,
          item.name,
          item.latitude,
          item.longitude,
          item.address,
          item.si,
          item.gungu,
          item.open_time,
          item.close_time,
          item.toilet_type,
          item.count_man,
          item.count_women,
          item.baby_yn,
          item.unusual_yn,
          item.cctv_yn,
          item.alarm_yn,
          item.pwd_yn,
          item.open_yn,
          item.etc,
          item.source_updated_at,
          item.last_synced_at,
          item.is_active,
        ],
      );
    }

    const toDeactivate = currentRows
      .filter((row) => !seenKeys.has(`${row.external_source}::${row.external_id}`))
      .map((row) => row.seq)
      .filter((seq): seq is number => typeof seq === "number");

    if (toDeactivate.length > 0) {
      await sql.unsafe(
        `update ${quotedTargetTable}
         set is_active = false, last_synced_at = $1
         where seq = any($2::int[])`,
        [new Date().toISOString(), toDeactivate],
      );
    }

    await updateRun(runId, {
      status: "success",
      finished_at: new Date().toISOString(),
      fetched_count: rawItems.length,
      upserted_count: normalizedItems.length,
      deactivated_count: toDeactivate.length,
      metadata: JSON.stringify({
        api_mode: apiMode,
        region_codes: regionCodes,
        sync_from: syncFrom,
        sync_to: syncTo,
        history_base_date: historyBaseDate,
        target_schema: targetSchema,
        target_table: targetTable,
      }),
    });

    return new Response(JSON.stringify({
      ok: true,
      runId,
      fetched: rawItems.length,
      upserted: normalizedItems.length,
      deactivated: toDeactivate.length,
    }), {
      headers: { "content-type": "application/json" },
    });
  } catch (error) {
    if (runId != null) {
      await updateRun(runId, {
        status: "failed",
        finished_at: new Date().toISOString(),
        error_message: JSON.stringify(formatError(error)),
      });
    }

    return new Response(JSON.stringify({
      ok: false,
      error: formatError(error),
    }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
