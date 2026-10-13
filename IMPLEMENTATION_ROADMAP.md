# LSY UV Repair — 개발 로드맵

이 문서는 개발 계획이다. 아래 PoC, 코드 작성, Max 테스트는 이번 요청에서 실행하지 않았다. 1명의 숙련된 개발자/TA와 에셋 담당자의 정기 검토를 가정하며, 1인일은 6–8시간이다. 기간은 추정이고 버전·실제 씬·호스트 API 검증 결과에 따라 달라진다.

## V0 — 기술 검증과 지원 범위 확정

예상 5–8인일. V1보다 먼저 수행하며 성공한 실험 결과만 제품 코드로 반영한다.

| PoC | 검증 내용 | 산출물/통과 게이트 |
|---|---|---|
| P0 환경·API | 정확한 Max build/Python/PySide, interface 서명, 채널 반환 규칙 | 환경 manifest, A01–A17 capability matrix |
| P1 native 가시성·기즈모 | 점 옵션, M/R/S, pivot, 축 드래그, 단일 점·선 선택·포커스·재개방 | Test A 재현 영상/로그, F01 옵션별 충족표 |
| P2 UV I/O·Undo | seam fixture에서 좌표 round-trip, Hold 기반 실시간 drag, Esc/exception | Test F, 1 drag=1 Undo, 연결/geometry 불변 |
| P3 재질·face 대응 | ID 1/2/3 및 2/7/42, 같은 평가 단계의 face ID·UV 대응 | Test E, sparse ID 및 texture graph 로그 |
| P4 알고리즘·규모 | 회전 shape exact match, 알려진 TD fixture, 50k UV 추출/쓰기 | Test B/D 축소판, bridge·render 분리 성능 기록 |

### G0 아키텍처 확정 규칙

P1이 전체 요구를 통과하면 B-native로 진행한다. F01 전용 Hover/스타일이나 F02 안정성이 부족하면 B의 backend 위에 C 화면을 구현한다. full custom backend 재작성은 하지 않는다. P2/P3가 실패하면 화면 제작보다 쓰기·평가 단계 대응 문제를 먼저 해결한다.

5–8인일 안에 네이티브 소실 문제를 해결하지 못하면 우회책을 무기한 늘리지 않고 재현 조건과 미지원 범위를 기록하여 custom 화면 PoC로 이동한다. custom 화면에서도 P2가 실패하면 V1 출시를 차단하고 SDK 또는 쓰기 경로 변경 비용을 재평가한다. UI 버튼만 있는 프로토타입을 V1로 출시하지 않는다.

## V1 — 기존 텍스처 위에서 안전하게 편집

전체 요구를 만족하는 custom 화면 경로 기준 V0 포함 **45–70인일**, 약 9–14개 근무 주. V1 자체는 40–62인일이다. V0와 병행 가능한 재질 분석을 포함하되 같은 시간을 중복 합산하지 않는다.

| 작업 묶음 | V1 인일 | 결과 |
|---|---:|---|
| session·snapshot·Max adapter·Undo | 8–12 | node/channel/revision 명시, round-trip·rollback |
| UV canvas·선택·zoom/pan·F01 | 10–15 | 배경/wire/point/hover/island 렌더링 |
| F02 실제 gizmo·pivot·live sync | 10–16 | M/R/S drag, axis 제약, 취소, 단일 Undo |
| F06 재질/이미지/자동·수동·고정 | 6–10 | Standard/Physical Bitmap, sparse ID, 혼합 정책 |
| 통합 실사용 검증·간단 설치·오류 진단 | 6–9 | Test A/E/F 통과, 재실행·닫기·scene 변경 안정화 |
| 합계 | 40–62 | V0 포함 45–70 |

개발량: 제품 및 테스트/진단 보조 코드 약 **4,000–7,000 LOC**. native가 full gate를 통과하면 V0 포함 25–40인일, 약 2,000–4,000 LOC로 재산정할 수 있다. 숫자는 생성된 코드량이 아니다.

G1: F01/F02/F06 전체 명세, Test A/E/F, 50k UV 성능 gate, 주요 무결성 검사 통과. 수동 배경 파일 대체는 지원하되 정상 Standard/Physical Bitmap의 자동 전환 실패를 대체 기능으로 숨기지 않는다. 배포/오류 처리는 V4까지 미루지 않고 이 시점부터 최소 수준을 갖춘다.

## V2 — 반복 작업 자동화

예상 25–40인일. 먼저 F03 Exact와 F04 Exact Stack, 그 후 같은 topology Approximate, 마지막으로 Align/Weld/Snap을 진행한다.

1. island graph·candidate bucket·정확한 correspondence.
2. 회전/scale/mirror 제약 solver와 대칭 모호성 UI.
3. material/texture 필터, reference 불변, ghost preview와 전체 rollback.
4. Exact 기반이 통과한 뒤 Approximate tolerance와 미판정 표시.
5. 추가 기능 Align/Snap → UV Weld → Straighten/Isolation 순서. Weld는 좌표 변경과 다른 topology 트랜잭션으로 분리.

G2: Test B/C/F 및 symmetry/negative fixtures 통과. 대응이 없는 다른 topology를 자동 stack하지 않음. Approximate candidate와 Exact 결과가 UI에서 구분됨. 필수 작업이 지연되면 추가 도구를 다음 patch로 옮긴다.

## V3 — 검사와 밀도

예상 15–25인일. F05 → Overlap → Distortion 순서다. V0에서 검증한 계산을 제품 UI에 연결한다.

- world-area/UV-area/비정사각 이미지/단위 테스트, Get/Set/Reference.
- 다중 해상도는 계산 가능한 범위와 N/A를 명확히 표시한다.
- 의도된 stack과 새 overlap을 구분하고 공유 edge 접촉을 overlap에서 제외한다.
- 왜곡은 density와 분리된 지표로 표시한다.
- 필수 기능 안정화 후 Before/After·Relax Selected를 검토한다.

G3: Test D/F, overlap/degenerate/flip 검사, density preview·Undo 통과. 특정 렌더러의 effective texture density 미지원은 raw UV density와 명확히 구분한다.

## V4 — LOD 복구 고도화와 배포 강화

예상 25–40인일. Reference UV Match → 복구 보조 → 프로파일링 → 지원 버전 확장·배포 강화 순서다.

동일 topology reference부터 지원한다. 다른 topology LOD는 geometry projection과 수동 anchor로 후보를 만들고 seam/material 제약·confidence·preview를 제공한다. occlusion, 가까운 반대면, 제거된 face 때문에 잘못된 surface를 고르는 경우를 테스트한다. 정보가 없는 부분은 자동 복원 완료로 표시하지 않는다.

다중 node/instance 지원, 타일별 이미지, renderer adapters, 큰 씬 최적화는 독립 옵션으로 출시한다. 무결성·Undo·실시간 편집을 회귀 검사하고 필요하면 C++ 병목만 교체한다. clean profile 설치/제거, 버전 매트릭스, 설정 이전, callback 해제, 사용자 가이드·문제 수집 방법을 완성한다.

G4: 대표 실제 에셋 세트에서 기존 수작업 대비 시간과 수정 정확도를 측정하고 지원 환경별 회귀 테스트 통과. 자동화로 생긴 texture 오류를 아티스트 검토로 확인한다.

## 합산·의존성·위험

| 단계 | 인일 범위 | 기준 토큰 배분(예비 포함) | 독립 검증 |
|---|---:|---:|---|
| V0 | 5–8 | 150k | 작은 disposable fixture |
| V1 | 40–62 | 650k | A/E/F + 성능 |
| V2 | 25–40 | 550k | B/C + topology Undo |
| V3 | 15–25 | 250k | D + 진단 기준 |
| V4 | 25–40 | 385k | 실제 LOD + 설치/호환성 |
| 전체 | **110–175** | **1,985k** | 단계별 출시 게이트 |

약 22–35 근무 주에 해당하며 대기·외부 리뷰·지원할 렌더러 추가는 포함하지 않는다. 이 단계 배분과 TOKEN_BUDGET의 작업 유형별 표는 **같은 예산을 다른 축으로 나눈 것**이므로 서로 더하지 않는다. V0+V1 기준 토큰은 800k다.

주요 위험은 native 요구 미충족, bridge 성능, live Undo, 평가 단계 face 대응, texture graph 의미 해석, 대칭 correspondence다. 각각 G0에서 조기 실험하거나 V2 preview/제약으로 통제한다. SDK 신규 backend, 모든 렌더러 지원, 원본 없는 완전 자동 복구는 현재 견적에 포함하지 않는다.
