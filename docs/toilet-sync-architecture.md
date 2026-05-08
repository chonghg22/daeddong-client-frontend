# 화장실 데이터 동기화 아키텍처

현재 앱은 Supabase의 `toilet` 테이블과 `get_nearby_toilets` RPC를 직접 조회한다.
따라서 행정안전부 `공중화장실정보 조회서비스`를 앱에서 직접 호출하지 말고,
서버 측 배치가 외부 API를 수집한 뒤 Supabase를 갱신하는 구조가 가장 안정적이다.

참고:

- 앱은 `public.toilet` 뷰 또는 공개 RPC를 읽을 수 있다.
- 동기화 작업의 실제 저장 대상은 `daeddong.toilet` 같은 내부 스키마 테이블일 수 있다.
- 따라서 sync 함수는 내부 스키마를 직접 갱신하고, 앱은 기존 조회 경로를 그대로 유지한다.

## 목표

- 앱 업데이트 없이 화장실 데이터 변경 반영
- 원본 API 응답과 최종 서비스 데이터를 분리
- 변경 이력과 동기화 로그 보존
- 잘못된 대량 삭제/오염에 대한 방어선 확보

## 권장 흐름

1. 스케줄러가 Edge Function `toilet-sync`를 호출한다.
2. Function이 `/info` 또는 `/history`를 페이지 단위로 수집한다.
3. 원본 응답을 `toilet_import_raw`에 저장한다.
4. 원본을 서비스 스키마로 정규화한다.
5. `toilet` 테이블에 `upsert` 한다.
6. 이번 실행에서 보이지 않은 기존 데이터는 즉시 삭제하지 않고 `is_active = false` 후보로 둔다.
7. 실행 결과를 `toilet_import_runs`와 `toilet_change_history`에 남긴다.

## 테이블 역할

- `toilet`
  앱이 직접 읽는 최종 서비스 테이블
- `toilet_import_runs`
  동기화 실행 단위 로그
- `toilet_import_raw`
  외부 API 원본 저장
- `toilet_change_history`
  어떤 값이 어떻게 바뀌었는지 기록

## 키 설계

외부 API가 안정적인 ID를 주면 아래 조합을 권장한다.

- `external_source`
- `external_id`

이 두 컬럼에 unique index를 둔다.

외부 ID가 없다면 임시로 아래 조합을 고려할 수 있지만, 오탐 가능성이 있다.

- `name`
- `address`
- 좌표 반올림값

이 경우는 자동 반영보다 검수 단계를 추가하는 편이 낫다.

## 삭제 정책

바로 `delete` 하지 말고 아래 순서를 권장한다.

1. 이번 동기화에서 누락된 데이터는 `is_active = false`
2. `missing_count` 또는 `missing_since` 누적
3. 여러 번 연속 누락되면 실제 삭제 또는 장기 비활성

## 권장 실행 주기

- 기본: 하루 1회
- 데이터 변동이 잦으면 6시간 1회
- 심야 시간대 권장

## 이 API 기준 권장 사용법

일반 동기화는 `/info`를 기준으로 한다.

- `serviceKey`
- `pageNo`
- `numOfRows=100`
- `returnType=json`
- `cond[DAT_UPDT_PNT::GTE]`
- `cond[DAT_UPDT_PNT::LT]`
- `cond[OPN_ATMY_GRP_CD::EQ]`

과거 스냅샷 확인이나 백필은 `/history`를 별도 작업으로 사용한다.

- `cond[BASE_DATE::EQ]`
- `cond[LAST_MDFCN_PNT::GTE]`
- `cond[LAST_MDFCN_PNT::LT]`

## 지역별 초기 적재 전략

전체 5만 건 이상을 한 번에 다루기보다 `..._ALL` 지역 코드를 이용해 나눠 적재하는 편이 안전하다.

예시:

1. `6110000_ALL` 서울 전체 적재
2. `6260000_ALL` 부산 전체 적재
3. 나머지 광역 단위 순차 적재

권장 방식:

- `TOILET_REGION_CODES`에 1~3개 정도만 넣고 배치 실행
- 실행 성공 후 다음 지역 묶음으로 진행
- 초기 적재 완료 뒤에는 지역 조건 없이 증분 동기화 또는 전체 광역 코드 분할 증분 동기화

## 비활성 처리 전략

우선순위:

1. 상태코드가 `03`, `04`, `05`
2. 상태명에 `폐업`, `취소`, `말소`, `만료`, `정지`, `중지`, `삭제`, `전출` 포함
3. `DAT_UPDT_SE`가 삭제 의미일 때

단, 현재 `/info` 샘플 응답에서는 상태코드 필드가 명확히 보이지 않았으므로 운영 전 실데이터로 재확인이 필요하다.

## 증분 동기화 전략

실호출 테스트 결과:

- `cond[DAT_UPDT_PNT::GTE]=20260501000000` 조건 동작 확인
- `cond[OPN_ATMY_GRP_CD::EQ]=6110000_ALL` 조건 동작 확인

따라서 운영 증분 흐름은 아래처럼 잡는다.

1. 마지막 성공 시각을 `YYYYMMDDHHMMSS`로 저장
2. 다음 실행 시 `TOILET_SYNC_FROM`에 마지막 성공 시각 주입
3. `TOILET_SYNC_TO`는 실행 시각 직전 값 사용
4. 성공하면 이번 실행 구간을 run metadata에 기록

## 장애 대응

- 외부 API 실패 시 기존 `toilet` 데이터는 유지
- 원본 건수 급감 시 전체 비활성화 금지
- 응답 포맷 파손 시 run 로그에 실패 기록 후 중단

## 현재 앱과의 연결점

- 목록 조회: `get_nearby_toilets`
- 상세 조회: `toilet`
- 제보 테이블: `report`

즉 동기화가 끝나면 앱 코드는 바꾸지 않아도 최신 데이터가 반영된다.

## 남은 작업

1. `/info` 미리보기 JSON 1건 확보
2. 실제 응답 필드와 `toilet` 컬럼 매핑 확정
3. Supabase secrets 등록
4. cron 배치 등록
5. 스테이징에서 1회 수동 검증
