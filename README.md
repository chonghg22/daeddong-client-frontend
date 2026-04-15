# 대똥여지도 / 기저귀갈이대 (daeddong)

Flutter 기반 공중화장실·기저귀갈이대 위치 지도 앱. 하나의 코드베이스에서 두 개의 앱(flavor)을 빌드한다.

---

## 앱 개요

| 항목 | 내용 |
|------|------|
| 플랫폼 | Android (현재 주력) |
| 언어/프레임워크 | Flutter (Dart) |
| 상태관리 | flutter_riverpod |
| 라우팅 | go_router |
| 지도 | flutter_naver_map |
| 백엔드 | Supabase (PostgreSQL) |
| 광고 | Google AdMob |
| 위치 | geolocator + permission_handler |

---

## Flavor (빌드 구분)

| Flavor | applicationId | 앱 이름 | AdMob App ID |
|--------|--------------|---------|-------------|
| `daeddong` | `kr.co.daeddong` | 대똥여지도 | `ca-app-pub-1242280591895560~...` |
| `babytoilet` | `kr.co.babytoilet` | 기저귀갈이대 | `ca-app-pub-1242280591895560~...` |

빌드 명령:
```bash
# daeddong flavor
flutter run --flavor daeddong -t lib/main_daeddong.dart

# babytoilet flavor
flutter run --flavor babytoilet -t lib/main_babytoilet.dart
```

---

## 프로젝트 구조

```
lib/
├── main.dart                   # 기본 진입점
├── main_daeddong.dart          # daeddong flavor 진입점
├── main_babytoilet.dart        # babytoilet flavor 진입점
│
├── core/
│   ├── constants/
│   │   └── app_constants.dart  # Supabase URL/Key, 네이버맵 ClientID, AdMob ID
│   ├── router/
│   │   └── app_router.dart     # GoRouter 라우트 정의
│   ├── theme/
│   │   └── app_theme.dart
│   └── widgets/
│       └── admob_banner_widget.dart
│
├── features/
│   ├── map/                    # 지도 화면 (메인)
│   ├── detail/                 # 화장실/기저귀갈이대 상세
│   ├── favorites/              # 즐겨찾기
│   └── report/                 # 정보 제보
│
├── data/
│   ├── models/toilet_model.dart
│   ├── datasources/toilet_remote_datasource.dart
│   └── repositories/toilet_repository.dart
│
└── providers/
```

### 화면 라우트

| 경로 | 화면 |
|------|------|
| `/map` | 지도 (초기 화면) |
| `/favorites` | 즐겨찾기 |
| `/detail/:seq` | 상세 조회 |
| `/report/:seq?name=` | 정보 제보 |

하단 네비게이션 바: 지도 / 즐겨찾기

---

## Android 설정

**android/app/build.gradle.kts**
- namespace: `kr.co.daeddong`
- compileSdk: flutter 기본값
- Java/Kotlin: VERSION_17
- 서명: `android/key.properties` (gitignore 대상)
- flavor dimension: `app`

**android/app/src/main/AndroidManifest.xml**
- 권한: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- 네이버맵 Client ID: `REDACTED_NAVER_CLIENT_ID` (meta-data)
- AdMob Application ID: meta-data로 주입 (현재 테스트 ID)
- 딥링크 queries: `nmap://` (네이버맵), `kakaomap://` (카카오맵)

---

## 외부 서비스 연동

### Supabase
- URL: `https://REDACTED_SUPABASE_HOST`
- Anon Key: `app_constants.dart`에 하드코딩
- 테이블: 화장실/기저귀갈이대 위치 데이터

### 네이버 지도 API
- Client ID: `REDACTED_NAVER_CLIENT_ID`
- AndroidManifest와 AppConstants 두 곳에 설정

### Google AdMob
- 릴리즈/디버그 자동 전환 (`dart.vm.product` 환경변수 활용)
- 디버그: 공식 테스트 광고 단위 ID 사용
- 릴리즈: flavor별 실제 광고 단위 ID 사용

### Google Play 앱 등록
- daeddong: `kr.co.daeddong`
- babytoilet: `kr.co.babytoilet`
- 서명 키: `android/key.properties` + keystore 파일 (별도 관리)

---

## 주요 외부 패키지

| 패키지 | 용도 |
|--------|------|
| `flutter_riverpod` | 상태관리 |
| `go_router` | 선언적 라우팅 |
| `flutter_naver_map` | 네이버 지도 |
| `geolocator` | GPS 위치 |
| `permission_handler` | 위치 권한 |
| `supabase_flutter` | 백엔드 API |
| `shared_preferences` | 로컬 저장 (즐겨찾기 등) |
| `google_mobile_ads` | AdMob 배너 |
| `url_launcher` | 외부 앱 연결 (지도 앱 등) |
| `flutter_launcher_icons` | 앱 아이콘 생성 (flavor별) |
