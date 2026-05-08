# toilet-sync

행정안전부 `공중화장실정보 조회서비스`를 수집해서 `toilet` 테이블에 반영하는
Supabase Edge Function 초안이다.

## 전제

- 현재 함수는 `https://apis.data.go.kr/1741000/public_restroom_info` 기준으로 맞춰져 있다.
- 기본 동기화 모드는 `/info` 이다.
- 필요하면 `/history` 모드로 과거 기준일 이력 조회도 가능하다.
- 응답 필드명은 실제 미리보기 JSON을 보고 `normalizeItem()`을 최종 확정해야 한다.

## 필요한 Secrets

Supabase project secrets:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `TOILET_SOURCE_NAME`
- `TOILET_API_BASE_URL`
- `TOILET_API_SERVICE_KEY`
- `TOILET_API_MODE`
- `TOILET_SYNC_FROM`
- `TOILET_SYNC_TO`
- `TOILET_HISTORY_BASE_DATE`
- `TOILET_REGION_CODES`
- `TOILET_TARGET_SCHEMA`
- `TOILET_TARGET_TABLE`

권장값:

- `TOILET_API_BASE_URL=https://apis.data.go.kr/1741000/public_restroom_info`
- `TOILET_API_MODE=info`
- `TOILET_REGION_CODES=6110000_ALL,6260000_ALL`
- `TOILET_TARGET_SCHEMA=daeddong`
- `TOILET_TARGET_TABLE=TOILET`

주의:

- 공공데이터포털에서 받은 인증키는 git에 넣지 말고 Supabase secret으로만 관리
- 포털에서 제공하는 Encoding/Decoding 키 중 실제 호출에 맞는 값을 사용

## 배포

```bash
supabase functions deploy toilet-sync
```

## 수동 실행

```bash
supabase functions invoke toilet-sync
```

## 모드

`info`

- 엔드포인트: `/info`
- 증분 동기화용
- 일반 운영 모드
- 사용 파라미터:
  `serviceKey`, `pageNo`, `numOfRows`, `returnType`,
  `cond[DAT_UPDT_PNT::GTE]`, `cond[DAT_UPDT_PNT::LT]`,
  `cond[OPN_ATMY_GRP_CD::EQ]`

`history`

- 엔드포인트: `/history`
- 특정 기준일 이력 백필용
- 사용 파라미터:
  `serviceKey`, `pageNo`, `numOfRows`, `returnType`,
  `cond[BASE_DATE::EQ]`,
  `cond[LAST_MDFCN_PNT::GTE]`, `cond[LAST_MDFCN_PNT::LT]`

## cron 권장

- 기본: 하루 1회
- 권장 시간: 새벽 시간대

## 반드시 검토할 부분

1. 미리보기 JSON 기준 실제 응답 필드명
2. 공중화장실 고유 식별자로 쓸 컬럼
3. `/info`의 `DAT_UPDT_PNT`와 `/history`의 `LAST_MDFCN_PNT` 포맷 확인
4. 누락 데이터의 비활성 처리 정책
5. `toilet` 테이블 실제 컬럼명과 migration 정합성

## 현재 구현 메모

- `MNG_NO`를 외부 고유키로 사용
- 실제 저장 대상 스키마는 기본값 `daeddong`
- 비활성 판정은 상태코드/상태명/삭제 갱신구분이 있을 때만 적용
- 초기 적재는 `TOILET_REGION_CODES`에 `..._ALL` 코드를 넣어 지역별로 쪼개서 실행 가능
- 증분 적재는 `TOILET_SYNC_FROM`, `TOILET_SYNC_TO`를 `YYYYMMDDHHMMSS` 포맷으로 사용
