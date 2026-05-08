# Play Store Assets

`대똥여지도` 플레이스토어 상세 페이지를 보강하기 위한 스토어용 자산 템플릿이다.

현재 앱 상세가 횡해 보이는 핵심 이유는 다음 두 가지다.

1. 설명형 스크린샷이 없다.
2. 핵심 기능이 한눈에 들어오는 카피와 비주얼이 없다.

이 폴더에는 바로 편집 가능한 `1080x1920` 세로 스크린샷 SVG 3종과 `1024x500` 피처 그래픽 SVG 1종을 넣었다.

## 포함 파일

- `copy.md`: 업로드용 카피 초안
- `templates/01-nearby-map.svg`: 주변 화장실 탐색 강조
- `templates/02-detail-guide.svg`: 상세 정보와 길찾기 강조
- `templates/03-favorites-report.svg`: 즐겨찾기와 정보 제보 강조
- `templates/feature-graphic.svg`: 플레이스토어 피처 그래픽 초안

## 권장 작업 순서

1. 실기기에서 아래 화면을 캡처한다.
2. SVG 안의 `SCREENSHOT` 영역에 실제 스크린샷을 배치한다.
3. SVG를 PNG로 export 한다.
4. Play Console에 스크린샷 3장 이상, 피처 그래픽 1장을 반영한다.

## 추천 캡처 화면

1. 지도 화면
2. 상세 화면
3. 즐겨찾기 또는 제보 화면

## 디자인 방향

- 앱 아이콘의 노란색과 지도/위생 계열의 녹색을 메인 톤으로 사용
- 검은 배경 플레이스토어에서도 눈에 띄게 밝은 대비 유지
- 문장 길이를 줄이고 한 장당 메시지 하나만 전달

## export 팁

디자인 툴 없이도 Figma, Illustrator, Inkscape, Photopea 같은 도구에서 SVG를 열어 PNG로 저장할 수 있다.

권장 출력:

- Phone screenshots: `1080x1920`
- Feature graphic: `1024x500`
