# LSY UV Repair — 기술 검증·테스트 계획

상태: **계획만 작성. 모든 Max 실행 테스트는 미실행(Not Run).** 문서·수식 검토와 호스트 동작 검증을 구분한다. API 근거는 [TECHNICAL_FEASIBILITY.md](TECHNICAL_FEASIBILITY.md), 동작 규칙은 [FEATURE_SPEC.md](FEATURE_SPEC.md)를 따른다.

## 환경·fixture·측정 규약

실행마다 Max 버전/build, Python/PySide/Qt, OS/DPI, CPU/GPU/RAM, scene units, renderer, material class, UV 수/face 수/선택 수, 이미지 해상도를 기록한다. 실제 사용자 버전 하나를 먼저 통과시키고 지원 버전마다 재실행한다. destructive fixture 준비는 개발 단계의 별도 disposable scene에서만 한다.

| Fixture | 구성 |
|---|---|
| S1 | plane + 분리 seam cube + 단일 UV 점/일직선 선택, identity Bitmap |
| S2 | 비대칭 L자/구멍 있는 island: translate, 37°/90° rotate, 2배 scale, mirror, 작은 noise 복제 |
| S2-negative | 같은 bbox 다른 shape, 같은 counts 다른 연결, 같은 경계 다른 내부, 같은 geometry 다른 seam |
| S2-symmetric | 정사각/원형 반복, 여러 동률 correspondence |
| S3 | world 100×100cm plane, UV unit square, 1024²/2048×1024 이미지 |
| S4 | 하나의 mesh + Multi/Sub ID 1/2/3 Wood/Metal/Fabric, 별도 2/7/42와 누락 slot |
| S5 | 최적화 이전/이후 쌍, Remove/Weld/Collapse/ProOptimizer 각각, channel 1/2/3, UDIM·음수 UV |
| S6 | 공유 instance·공유 modifier·다중 node·지원하지 않는 Patch/animated UV |
| S7 | 5k/50k/200k UV points, 1k/5k/50k 선택, 1k/4k/8k 이미지 |

좌표 epsilon은 일반 UV 1e-6, 재현 가능한 round-trip은 가능하면 동일 값 비교. geometry 위치 비교는 씬 크기에 맞는 epsilon을 별도로 기록하고 count/연결/ID/참조는 정확 일치를 요구한다. 잔차는 UV norm과 texture pixel norm을 모두 기록한다.

## Test A — 실제 선택·기즈모·드래그

구현/API: native A01–A03, custom A04/A15/A16. 난이도 5, 주요 위험은 상태·focus·Undo/실시간 반영이다.

1. S1에서 Vertex/Edge/Island 각각 선택하고 Move/Rotate/Scale, U/V/자유/균일 모드를 실행한다.
2. 단일 점·일직선·겹친 점·일반 island, zoom 25/100/400%, DPI 100/150/200%를 검사한다.
3. pivot center/custom 이동, selection 변경, 창 재개방, Modify context 전환, viewport↔editor focus 전환을 반복한다.
4. 각 모드 최소 100 drag, 전체 선택/모드 전환 스트레스 1,000회. 클릭 좌표·기즈모 상태·실제 UV 좌표·Undo 수를 기록한다.
5. 포인터를 실제 핸들 위에서 눌러 이동한다. 숫자 API로 좌표만 바뀌는 것은 통과가 아니다.

완료: 선택 후 100ms 이내 hit 가능한 기즈모가 나타남(대표 씬 목표), 1,000회에서 소실·잘못된 mode 0회. U 이동은 V/W 불변, rotate는 pivot 거리 보존, scale은 요청 비율, selection 변경만으로 좌표 변화 없음. live viewport p95 ≤100ms, canvas p95 ≤33ms(S7의 50k/5k 기준). 한 drag=한 Undo, Esc는 원좌표. F01 선택/비선택 색·크기·hover·edge/island 강조도 모두 확인한다. 제한된 반복에서 통과한 사실을 영구 무결함 보증으로 표현하지 않는다.

## Test B — 회전·Mirror·유사도

구현/API: A04 연결 추출, 자체 graph/정합, A03 선택. 난이도 4–5.

S2/S2-negative에서 Exact/Approximate, scale normalization, rotation/mirror 옵션을 조합한다. 회전 허용 시 37°/90° 복제가 검색되고 mirror off일 때 비대칭 mirror는 제외되어야 한다. Scale off는 2배 복제를 제외하고 on이면 포함한다. point/face index를 재번호화한 동일 topology도 찾는다.

완료: 설계된 Exact 양성/음성 fixture에서 precision/recall 모두 100%. bbox/counts만 같은 음성 0개 오선택. 동일 boundary·다른 내부 shape는 탈락. Approximate에서 tolerance 바로 위/아래 데이터가 임계에 맞게 분류되고 정규화 RMS·최대 잔차가 표시된다. 대칭은 모호성을 표시하고 선택 후보와 Stack 승인 상태를 구분한다. timeout은 미판정이다. 실제 production 세트는 아티스트 라벨과 confusion matrix를 별도로 작성한다.

## Test C — 버텍스 대응 기반 Stack

구현/API: F03 correspondence + 자체 constrained solver + A04/A14. 난이도 5.

1. 비대칭 S2의 rotated copy를 reference에 stack한다.
2. Translate only, Rotate on/off, Uniform Scale on/off, Mirror on/off 각각 결과를 확인한다.
3. 대응 index 순서가 다른 copy, 대칭 후보, 다른 texture 영역, 다른 Material ID, 다른 node의 같은 숫자 ID를 검사한다.
4. preview 취소와 적용, 전체 후보 중 한 건 실패 시 rollback을 실행한다.

완료: Exact 대응 최대 오차 ≤1e-5 UV 및 4K에서 ≤0.1 px. reference 좌표 정확 불변, UV 연결/geometry/재질 불변. 비활성 transform이 쓰이지 않음. 기준 밖·미판정·모호한 대응은 자동 적용 안 됨. preview에서 예상 UV와 적용 후 UV 일치. Undo 한 번에 원위치, Redo에 동일 결과. Approximate는 잔차를 남긴 채 정합하며 변형시켜 몰래 exact 처리하지 않는다.

## Test D — Texel Density 기준 계산

구현/API: 자체 같은 corner triangulation/world-area 계산, A04/A17 교차검산, A14 Set. 난이도 3–4. 아래 값은 수학적 oracle이며 Max 실행 측정값이 아니다.

| 입력 | 기대 결과 |
|---|---|
| 100×100cm, UV 면적 1, 1024² | sqrt(1,048,576 / 10,000) = **10.24 px/cm** |
| 같은 plane, 2048×1024 | sqrt(2,097,152 / 10,000) ≈ **14.48154688 px/cm** |
| UV를 U/V 모두 0.5배 | 면적 0.25배, 밀도 0.5배 |
| world를 균일 2배 | world 면적 4배, 밀도 0.5배 |
| plane의 world X만 2배 | 면적 2배, 밀도 10.24/sqrt(2) ≈ **7.24077344 px/cm** |
| 10.24에서 target 20.48 | UV uniform scale 2, 면적 4배 |
| 물리 크기 같은 1m 표기 plane | **1024 px/m = 10.24 px/cm** |

검사: negative scale, mirror UV, concave N-gon, 겹친 shell, zero UV/geometry area, 서로 다른 resolution 그룹, 채널 1/2, 타일 경계 crossing. 분리된 shell의 단순 평균과 전체 면적 밀도가 다르게 나오는 fixture도 포함한다. effective bitmap mapping 미지원이면 N/A 또는 raw mode를 명확히 표시해야 한다.

완료: 비퇴화 fixture의 절대/상대 비교 중 상대오차 ≤0.1%, Set 후 target 오차 ≤0.1%. reference copy가 단위 변환 후 동일 density를 만든다. min/max/평균은 명시한 집계와 일치. preview/Undo는 패턴 영향과 원래 UV 복원을 확인한다. production 계산 결과를 같은 구현으로 다시 계산한 값만 oracle로 사용하지 않는다.

## Test E — Multi/Sub Material ID 배경

구현/API: A08–A12 → A06/A07, 선택 A03. 난이도 4.

S4의 ID 1 → Wood_D, 2 → Metal_D, 3 → Fabric_D를 반복 선택한다. 실제 선택 face ID, resolved slot/material/map/path, 표시 이미지 request revision을 기록한다. 선택을 유지한 채 외부에서 Face ID를 바꾸는 경우도 검사한다.

추가: sparse ID 2/7/42, slot 순서 뒤바뀜, 중첩 Multi/Sub, 같은 path 재사용, 미할당 slot, 꺼진 Base Color map, Base Color와 Normal/ORM 동시 연결, color-correction/composite, 파일 없음, manual 파일, 복수 ID/빈 선택, lock/unlock, 빠른 선택 변경 중 늦게 끝나는 image load, UV channel mismatch.

완료: 정상 1/2/3 및 sparse ID에서 올바른 이미지 100%; cached 전환 ≤200ms 목표. 큰 파일 cold load는 시간 기록과 loading 표시. 혼합 선택은 기존 배경 유지+혼합 표시. 고정 시 전환 없음, unlock 후 현 선택으로 갱신. callback/폴링은 선택 불변 ID 변경도 감지. stale async 결과가 최신 배경을 덮어쓰지 않음. raw bitmap과 composited appearance를 혼동하지 않고 미지원은 수동 경로 제공. 원래 node.material/face ID/map 연결은 변하지 않는다.

## Test F — Undo/Redo·무결성·실패 복구

구현/API: A04/A05/A14/A15. 난이도 5.

일반 move/rotate/scale, Stack, Density Set 각각 전 snapshot → apply → Undo → Redo를 최소 100 cycle 수행한다. UV Weld는 별도 topology 명령으로 검사한다. native/custom 전환, 외부 Undo, 창 종료, scene reset, node 삭제, modifier 변경, texture load 실패, 쓰기 중 예외를 주입한다.

| 비교 항목 | 일반 UV 좌표 명령 기대 |
|---|---|
| geometry XYZ·면 연결·count·node transform | 전후 정확 동일 또는 위치 허용 epsilon 내 |
| UV face corner 연결·seam·point count | 정확 동일 |
| 비선택 UV/다른 채널/vertex color/W | 정확 동일 |
| face Material ID·node.material·sub-material·texture 참조 | 정확 동일 |
| modifier 순서·다른 modifier 상태 | 정확 동일 |
| Undo 후 대상 UV | 원 snapshot으로 복원 |
| Redo 후 대상 UV | apply 결과로 복원 |
| Esc/focus loss/예외 | 변경 없음, 새 Undo 오염 없음 |
| UV Weld Undo | 이전 UV topology와 좌표 모두 복원, geometry 불변 |

완료: 부분 적용·silent failure 0건, drag 한 번에 UV Undo 항목 하나, 사용자 이전 Undo 기록 보존. 예외가 pymxs 블록 밖으로 전파되지 않아도 실패 UI/로그가 남는다. 다른 작업의 Hold를 취소하지 않는다. topology revision이 바뀌면 이전 index 쓰기 0회. 복구 불가 상태는 정확히 알리고 추가 쓰기를 중단한다.

## 데이터 무결성 추가 시나리오

- S5의 Collapse/Remove/Weld/ProOptimizer **완료 후** 세션을 열고 현재 mapping을 보존한다. 편집 도중 아래 topology가 바뀌면 invalidation 후 재읽기한다.
- 위/아래 topology-changing modifier가 있는 stack에서 같은 단계 대응을 입증하지 못하면 편집 차단. base face ID를 잘못 참조하지 않음.
- 논리 채널 1/2/3 및 Vertex Color 구분: A13의 비대칭 get/set 규칙을 읽기/쓰기 round-trip으로 검증한다.
- UV -1.2 또는 2.3 등도 그대로 유지. UDIM 1001/1002/1011 및 경계 정확 좌표에서 불필요한 wrap 없음.
- intentional overlap은 새 seam으로 분리하지 않음. overlap 검사에서는 공유 edge/점 접촉을 면적 overlap으로 오인하지 않음.
- V1 instance/shared modifier/multi-node 미지원 경로는 쓰기 차단 및 이유 표시. 향후 지원 시 영향받는 전체 instance를 표시하고 Undo 전체 복원.
- animated UV, Patch, missing map channel, degenerate face, non-manifold, dead UV vertex를 감지하고 silent conversion 금지.

## 성능·UI lifecycle·회귀

S7에서 extract, island build, similar candidate, solve, host write, viewport, paint, hit-test, image decode를 따로 측정한다. 50k UV/5k 선택 목표는 Test A와 같다. 200k는 stress profile로서 목표 미달이면 지원 한도 또는 최적화 계획을 기록한다. 백그라운드 작업 취소 응답 ≤250ms 목표, 메인 스레드 장기 정지 금지.

30분 사용·창 재실행 50회·scene 열기/닫기 20회에서 callback 중복·닫힌 UI 접근·지속 메모리 증가를 검사한다. 첫 warmup 이후 닫기/GC 기준 메모리 증가 목표 10% 이하, cache 상한은 실제 image 메모리 예산으로 명시한다. 지원하는 PySide2/6 버전과 DPI별 focus/단축키/마우스 capture를 검사한다.

각 실패 기록: test ID, fixture, 환경, 단계, expected/actual, snapshot diff, 화면 영상, 재현 빈도. G1은 A/E/F, G2는 B/C, G3는 D와 검사 기능, G4는 실에셋/호환성/배포 통과가 필요하다. 구현 함수를 그대로 흉내 내는 테스트보다 독립 수치 oracle과 씬 불변식 검사를 우선한다.
