# Supabase Sync Runbook

앱 코드 변경 없이 화장실 데이터를 최신화하기 위한 Supabase 적용 순서다.

## 1. Migration 반영

먼저 DB 스키마를 반영한다.

```bash
supabase db push
```

반영 대상:

- `supabase/migrations/20260508_toilet_sync_tables.sql`

## 2. Secrets 등록

프로젝트 secrets에 아래 값을 등록한다.

```bash
supabase secrets set \
  TOILET_API_BASE_URL=https://apis.data.go.kr/1741000/public_restroom_info \
  TOILET_API_MODE=info \
  TOILET_API_SERVICE_KEY=... \
  TOILET_TARGET_SCHEMA=daeddong \
  TOILET_TARGET_TABLE=TOILET \
  TOILET_REGION_CODES=6110000_ALL,6260000_ALL \
  TOILET_SYNC_FROM=20260101000000 \
  TOILET_SYNC_TO=20261231235959
```

필수:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `TOILET_API_SERVICE_KEY`

권장:

- `TOILET_API_BASE_URL`
- `TOILET_API_MODE`
- `TOILET_TARGET_SCHEMA`
- `TOILET_TARGET_TABLE`
- `TOILET_REGION_CODES`
- `TOILET_SYNC_FROM`
- `TOILET_SYNC_TO`
- `TOILET_HISTORY_BASE_DATE`

## 3. Function 배포

```bash
supabase functions deploy toilet-sync
```

## 4. 초기 적재

처음에는 전국 전체를 한 번에 하지 말고 광역코드 기준으로 나눠서 한다.

권장 순서:

1. `6110000_ALL,6260000_ALL`
2. `6270000_ALL,6280000_ALL,6290000_ALL`
3. `6300000_ALL,6310000_ALL,5690000_ALL`
4. `6410000_ALL,6530000_ALL`
5. `6430000_ALL,6440000_ALL`
6. `6540000_ALL,6460000_ALL`
7. `6470000_ALL,6480000_ALL,6500000_ALL`

각 배치마다:

1. `TOILET_REGION_CODES` 수정
2. `supabase secrets set ...`
3. `supabase functions invoke toilet-sync`
4. `toilet_import_runs` 확인
5. `toilet` 테이블 적재 건수 확인

## 5. 증분 동기화 전환

초기 적재가 끝나면 `TOILET_REGION_CODES`를 비우거나 운영 정책에 맞게 유지하고,
`TOILET_SYNC_FROM`, `TOILET_SYNC_TO`만 움직이며 `/info` 기반 증분 동기화를 수행한다.

권장 규칙:

- `TOILET_SYNC_FROM`: 마지막 성공 실행 시각
- `TOILET_SYNC_TO`: 현재 실행 직전 시각

포맷:

- `YYYYMMDDHHMMSS`

예:

```bash
supabase secrets set \
  TOILET_SYNC_FROM=20260508000000 \
  TOILET_SYNC_TO=20260508235959
```

## 6. 검증 쿼리

적재 후 확인 포인트:

- `toilet` 전체 건수
- `is_active = false` 건수
- 최근 run 상태
- 최근 change history

예시:

```sql
select count(*) from daeddong."TOILET";
select count(*) from daeddong."TOILET" where is_active = false;
select * from daeddong.toilet_import_runs order by id desc limit 10;
select * from daeddong.toilet_change_history order by id desc limit 20;
```

## 7. 운영 주기

권장:

- 초기 적재: 수동
- 안정화 이후: 하루 1회 cron

## 8. 주의사항

- 인증키는 절대 git에 넣지 않는다.
- `DAT_UPDT_PNT`는 실제 응답 기준으로 공백 포함 시각 문자열이므로,
  조건값은 API가 요구하는 `YYYYMMDDHHMMSS` 포맷으로 준다.
- 상태코드/상태명 필드는 운영 중 샘플을 더 모아 폐업 판정을 한 번 더 검증하는 편이 안전하다.
