# LSY UV Repair — 기능 명세

상태: 설계 제안, 런타임 미검증. API 번호 A01–A17과 원문 링크는 [TECHNICAL_FEASIBILITY.md](TECHNICAL_FEASIBILITY.md)의 근거표를 따른다. 아래 수치·정책·알고리즘은 본 프로젝트의 제안이며 기존 제품의 동작을 인용한 것이 아니다.

## 공통 편집 규약

편집 대상은 node + modifier + logical UV channel + topology revision 조합으로 식별한다. Material ID, UV Map Channel, UDIM tile은 서로 다른 값이다. UI에서도 각각 독립 필드로 표시한다. 빈 선택은 '전체 선택'으로 자동 해석하지 않는다. UV의 W는 이동·회전·스케일에서 보존한다.

Island는 geometry edge를 공유하고 해당 edge 양 끝의 UV 인덱스도 연결된 면들의 연결 성분으로 정의한다. 같은 좌표에 겹친 서로 다른 UV 점은 연결로 간주하지 않는다. 점 하나만 접한 면들은 별도 island로 취급한다. 비정상적으로 서로 다른 geometry가 같은 UV 인덱스를 공유하면 독립 이동이 불가능하므로 진단 후 쓰기를 막는다.

### F01 — Vertex Visibility (V1)

- Vertex Size: 선택/비선택 점 각각 3–12 logical px 제안, 초기 6/4. native 적용 가능 범위는 A01과 실측을 따른다.
- Selected/Unselected Color, Hover Color, Edge Color를 분리한다. 선택은 밝기·테두리로도 구분한다.
- Hover는 선택을 변경하지 않는다. 기본 hit 반경 6 logical px, zoom과 독립, DPI 배율 반영.
- Island Highlight는 선택 면 반투명 fill + 경계 강조. 텍스처를 가리지 않도록 불투명도 조절.
- 텍스처 위 명암이 바뀌어도 점·선 윤곽 유지. 시각 크기와 선택 hit 반경을 별도 설정한다.
- native 설정은 원래 값을 저장하고 종료 시 사용자가 세션 중 바꾼 값을 무조건 덮어쓰지 않도록 소유 변경만 복원한다.

네이티브 A01은 선택 점·선·색 일부에만 직접 대응한다. 비선택 점 독립 스타일, Hover, 임의 island 강조를 미검증 상태로 완료 처리하지 않는다. 전체 옵션을 충족하지 못하면 커스텀 CanvasRenderer가 필요하다.

### F02 — Reliable Transform Gizmo (V1)

Vertex/Edge/Island 선택 지원. edge/island 선택은 중복 없는 UV point 집합으로 변환한다. face 선택은 재질 판정과 island seed에도 사용한다. 겹친 점의 선택은 반복 클릭 순환과 선택 목록으로 모호성을 해소한다. Marquee는 기본 완전 포함, 별도 교차 포함 옵션을 제공한다.

| 조작 | 요구 동작 |
|---|---|
| Move | U, V 축 핸들 및 중앙 자유 이동; screen delta를 UV delta로 변환 |
| Rotate | 회전 링을 잡아 pivot 기준 회전; 시작 방향과 현재 방향 차이로 계산 |
| Scale | 중앙 균일, U/V 개별 핸들; 기본 양수 scale, mirror는 별도 명시 옵션 |
| Pivot | 기본 선택 UV bbox 중심; 평균점·사용자 좌표·수동 이동 옵션 |
| 선택 변경 | 드래그 중에는 대상 고정. 드래그 종료 후 선택 변경 시 pivot 정책에 따라 갱신 |
| 확대/축소·Pan | 이미지와 UV가 동일 좌표 변환 사용. 화면만 움직이고 실제 UV는 불변 |
| 취소 | Esc, 창 닫기, focus loss, node 삭제/대상 변경 시 원상 복구 |

custom drag 상태는 Idle → HoverHandle → Dragging → Commit/Cancel → Idle이다. mouse press에서 대상·원좌표·pivot·시작 pointer·revision을 저장한다. 매 move는 **원좌표에서** 변환하여 누적 부동소수 오차를 피한다. 0길이 반경·축 분모는 최소 화면 거리로 보호한다. release에서 최종 좌표를 쓰고 하나의 Undo로 닫는다.

드래그 중 UV 화면과 3D Viewport 모두 갱신해야 한다. release에서만 Max 데이터를 쓰는 버전은 정식 완료가 아니다. 선택 점 하나 또는 일직선 선택에서도 hit 가능한 기즈모 크기를 유지한다. UI 화면의 y-down과 UV의 v-up, 비정사각 이미지 종횡비를 일관되게 처리한다. 조작 수학은 UV 공간, 밀도 검사는 pixel 공간이며 두 모드를 혼동하지 않는다.

네이티브 경로는 A02/A03으로 모드·피벗을 관리한다. 정해진 형태의 핸들만 고집하지 않되 사용자가 마우스로 실제 M/R/S를 수행할 수 있어야 한다. 상태 정합성을 맞춰도 사라짐이 재현되면 custom 경로로 전환한다.

### F03 — Select Similar UV Islands (V2)

입력: 명시한 reference island, 검색 범위, Exact/Approximate, 회전 허용, mirror 허용, 크기 정규화 여부, tolerance, Material ID/재질/텍스처 필터. 기본은 동일 node/channel/Material ID, mirror off, 크기 정규화 off.

1. UV 점 수·면 수·각 면 차수·경계 loop 수·연결 구조·면적 등으로 후보를 줄인다. bbox는 사전 필터에만 사용한다.
2. 면-corner 연결을 보존하는 그래프 대응을 구한다. 점 valence/경계 여부/이웃 면 차수 등의 label로 분할하고, 남은 대칭 후보는 bounded backtracking한다.
3. 대응 점으로 translation/rotation/(옵션) uniform scale/reflection 최적 정합을 계산한다.
4. 내부 점을 포함한 전체 잔차, 정규화 edge 길이 비, 모든 외곽/구멍 경계, 면적 비를 검사한다. 경계만 같고 내부가 다른 경우 exact에서 탈락시킨다.
5. 후보별 score·잔차·mirror·scale·모호성·필터 이유를 표시하고 선택한다.

Exact의 구조는 UV face incidence까지 동일해야 하며 단순 점/면 개수 일치가 아니다. 기본 최대점 잔차는 `max(1e-6 UV, reference 대각길이 × 1e-5)`, RMS는 같은 기준 이하를 제안한다. 거의 0면적/점 island는 degenerate로 별도 표시한다.

Approximate의 초기 지원은 **동일 topology, 변형된 shape**다. 기본 정규화 RMS 0.005, 최대점 잔차 0.01 이하를 제안하며 경계·면적 비 기준도 함께 통과해야 한다. tolerance를 크게 하면 위험 후보가 늘어남을 UI에 표시한다. 다른 topology의 유사 외곽 검색은 V4 검토 대상으로, correspondence 없는 후보를 자동 Stack에 넘기지 않는다.

회전은 연속 각도에 대해 판정한다. mirror를 켜면 반사 변환 후보도 평가하고 결과에 명확히 표시한다. 정사각형/원형 등 대칭으로 여러 대응이 동일 점수이면 기준 edge 또는 두 anchor를 요청하는 **도구 내부 UX**를 제공한다. 임의 대응을 '정답'으로 숨기지 않는다. 검색은 취소 가능하고 시간 초과 후보는 불일치가 아닌 미판정으로 표시한다.

### F04 — Stack Similar UV Islands (V2)

reference는 명시적으로 지정하고 쓰지 않는다. F03의 전체 point correspondence와 사용자 제약에 맞춘 2D 정합을 사용한다. 목표는 `q ≈ s R M p + t`; M은 mirror 옵션일 때만 반사, s는 uniform이다. Translate only면 R/M/s를 고정한다. Rotate off, Scale off 등 비활성 옵션을 solver가 몰래 사용하지 않는다.

- 기본 Translate+Rotate, Scale/Mirror off. texture가 이미 완성된 작업이므로 적용 전 전후 ghost preview 필수.
- 기준 island ID, 영향 face, 재질/이미지 경로, UV tile 변경, scale/mirror, RMS·최대 pixel 잔차를 표시한다.
- 같은 Material ID라도 다른 texture 영역에 놓였으면 결과가 달라진다. 필터는 안전의 충분조건이 아니므로 원래 영역과 새 영역을 모두 보여준다.
- 같은 숫자 ID라도 다른 node의 material이면 동일 재질로 판정하지 않는다. resolved material identity/texture identity도 비교한다.
- Exact에서는 전체 대응 잔차가 기준 이하일 때만 적용. 점별 reference 좌표 덮어쓰기로 shape를 변형하는 것은 기본 Stack이 아니다.
- Approximate는 rigid/similarity fit preview만 가능하며 오차를 표시한다. 완전 일치를 원해 개별 점을 변형하는 기능은 V4 Reference Match로 분리한다.
- UV seam/face-corner 연결은 바꾸지 않는다. 기존 overlap 의도는 유지하고 새 overlap은 preview에 포함한다.

기준: Exact fixture의 잔차 ≤1e-5 UV 및 4K 기준 ≤0.1 px. 허용오차 밖, 불명확한 대응, 누락된 텍스처는 기본 적용 차단 또는 명시적 검토 대상이다. Undo 한 번으로 후보 전체를 복원한다.

### F05 — Texel Density (V3, 계산 PoC는 V0)

Get, Set, Reference copy를 제공한다. 단위는 px/cm 기본, px/m 선택. texture 폭 W·높이 H를 명시하고 자동 탐색 값도 표시한다. 씬 표시 단위 대신 **시스템 단위 → 물리 단위 변환**을 사용한다.

같은 평가 단계의 각 삼각형 t에 대해:

- `A_world,t = 0.5 × |(P1−P0) × (P2−P0)|`. P는 node 변환(비균일 스케일 포함)을 적용한 물리 좌표.
- `A_uv,t = 0.5 × |det(U1−U0, U2−U0)|`.
- 단일 이미지·기본 UV 매핑일 때 `A_pixel,t = W × H × A_uv,t`.
- island 밀도 `D = sqrt(sum A_pixel,t / sum A_world,t)`.
- Set 배율 `s = D_target / D_current`; island pivot에 대해 U/V 모두 s배. translation/rotation은 하지 않는다.

이는 면적 등가 선형 밀도다. 비정사각 이미지에 `(W+H)/2`를 대입하지 않는다. 방향별 밀도가 다를 수 있으며 왜곡/이방성은 pixel mapping Jacobian의 특이값으로 별도 보고한다. 면적이 같아도 stretch가 같다는 뜻은 아니다.

N-gon은 동일한 corner triangulation을 UV와 geometry에 적용한다. concave face에 무조건 triangle fan을 쓰지 않는다. 음수 winding은 면적 절댓값으로 계산하되 뒤집힘 경고는 유지한다. 겹친 shell은 표면별 픽셀 할당을 각각 계산하며 UV union 면적을 쓰지 않는다.

통계는 island별 D, 단순 평균/min/max, 전체 면적 기준 `sqrt(총 pixel면적/총 world면적)`를 **다른 이름**으로 제공한다. min/max가 island 기준임을 표시하고 triangle 분포는 상세 창에서 따로 제시한다. resolution 불명·3D 면적 0·UV 면적 0은 N/A로 표시하며 Set을 막는다.

여러 Material/UDIM 해상도가 섞이면 face/tile별 pixel 면적을 합산한다. V3 초기 Set은 하나의 알려진 해상도 그룹 안에서만 지원한다. 서로 다른 해상도 타일을 가로지르는 face는 tile 경계 clipping 또는 미지원 표시가 필요하며 임의 평균으로 계산하지 않는다. bitmap tiling/offset/rotation이 identity가 아니면 V3 기본값은 raw UV density로 명시하고, effective density는 검증된 2D 맵 변환에만 지원한다. procedural/triplanar/world-space 맵은 N/A다.

Set 전에 UV 영역/패턴/타일 변화 및 기존 텍스처 영향 경고와 ghost preview를 보여준다. reference copy는 밀도 **숫자와 단위**를 복사한다. UDIM 경계를 넘는 이동을 자동 wrap하거나 clamp하지 않는다. Undo/Redo 필수.

### F06 — Material ID Texture Background (V1)

경로: 선택 face → 동일 평가 단계의 face Material ID → Multi/Sub materialIDList에서 슬롯 검색 → materialList의 sub-material → 의미가 명확한 Base Color/Diffuse → texture graph → 배경.

| 상황 | 동작 정책 |
|---|---|
| Face들이 ID 하나 | 해당 ID와 해석된 이미지로 자동 전환 |
| 여러 ID 동시 선택 | 기존 배경 유지 + '혼합 선택' + ID 목록. 임의 첫 face 기준 자동 전환 금지 |
| 선택 없음 | 현재 배경 유지, '선택 없음' 표시 |
| Vertex/Edge 선택 | 연결 face의 ID 집합으로 판정, 복수면 동일 혼합 정책 |
| 수동 ID | 자동 선택 추적을 일시 중지하고 명시 ID 표시 |
| 배경 고정 | 선택/ID 변경으로 이미지가 바뀌지 않음. unlock 시 현 선택에서 재해석 |
| Face ID가 외부에서 변경 | selection이 같아도 revision/재질 매핑 캐시 무효화 후 재탐색 |
| 파일 누락·미지원 맵 | 마지막 이미지에 stale 표시 후 수동 파일 선택 제공; 잘못된 이미지로 조용히 대체 금지 |

비연속 ID 2/7/42를 슬롯 2/7/42로 바로 접근하지 않는다. native `setMatID` 필터 index와 실제 ID 매핑도 별도로 관리하며, 불명확하면 A06으로 원하는 map을 직접 등록·선택한다. addMap의 중복 등록을 막고 네이티브 목록 index 캐시는 창 재개방/재질 변경 시 재구성한다.

재질 resolver는 Standard/Physical을 V1 검증 대상으로 한다. 중첩 Multi/Sub는 해당 계층 ID 매핑을 적용하되 Blend/Layered/renderer-specific 분기는 의미가 달라 후보 목록을 표시한다. graph visited set, depth/node 수 제한으로 cycle을 막는다. Base Color 가지를 먼저 선택한 후 탐색하여 Normal/ORM의 첫 bitmap을 잘못 채택하지 않는다. 파일명 `_D`만으로 확정하지 않는다.

ColorCorrection/Composite 같은 노드는 leaf bitmap과 최종 appearance가 다를 수 있다. 단일 원본 Bitmap을 보여주는 경우 '원본 이미지'임을 명시한다. full graph 결과 미리보기는 호스트 map 평가 경로 PoC 이후 확장한다. 미지원 재질도 수동 파일로 작업 가능하다. Normal/ORM/Custom은 선택 가능한 추가 배경이며 color/data 표시 구분과 ORM 채널 선택을 향후 제공한다.

배경은 렌더링/이미지 캐시만 사용하며 node.material, face ID, material graph를 변경하지 않는다. viewport는 원래 재질을 유지한다. texmap의 UV channel이 편집 채널과 다르면 표시하고 자동 채널 변경은 하지 않는다. 실제 텍스처의 tiling·rotation·crop·UDIM·OCIO 상태와 raw bitmap 차이를 명시한다. V1 정합 보증은 identity 2D Bitmap으로 한정하고 나머지는 manual/reference display로 구분한다.

## 추가 기능 우선순위

필수 기능의 기반 구현을 먼저 안정화한다. Island 선택은 F02 필수이므로 후보 기능에서 V1 기반으로 승격한다. 나머지 도구는 해당 단계 핵심 기능 통과 후 추가한다.

| 후보 | 단계/우선순위 | 방식·난이도 | 한계·완료 기준 |
|---|---|---|---|
| UV Island Selection | V1/P0 | 연결 그래프, 2 | 겹친 좌표를 연결하지 않음 |
| UV↔Geometry Selection Transfer | V1 내부 대응, 공개 도구 V2/P1 | corner 매핑, 3 | seam의 1:N을 표시, geometry 좌표 불변 |
| Align U/V | V2/P1 | 지정 축 좌표 정렬, 2 | 한 번 Undo, 타 축 불변 |
| Weld by Threshold | V2/P1 | UV topology 변경 명령, 4 | geometry weld 금지, 결과 seam preview/백업 |
| UV Vertex Snap | V2/P1 | screen hit + UV target, 3 | zoom/DPI 독립, 기본 weld 없음 |
| Straighten UV Edge | V2/P2 | chain 순서·anchor·투영, 3 | branch chain은 적용 차단 |
| UV Island Isolation | V2/P2 | 표시 mask, 2 | 씬 hide/geometry 변경 없음 |
| 선택 island 면적·정보 | V2/P2 | 분석 캐시, 2 | units/해상도 명시 |
| Overlap Detection | V3/P1 | broad phase + triangle intersection, 4 | 경계 접촉/의도된 stack 분리 |
| Distortion Detection | V3/P1 | triangle Jacobian singular values, 4 | degenerate와 flip 별도 표시 |
| Relax Selected | V3/P2 | 검증한 native 명령 또는 solver, 4 | texture 보존 아님, 경계 pin/preview 필요; API 재조사 |
| Before/After Comparison | V1 내부 snapshot, 공개 도구 V3/P2 | UV overlay/같은 camera 비교, 3 | topology 바뀌면 비교 제한 |
| Match UV to Reference | V4/P1 | 동일 topology 대응, 다른 topology는 표면 투영+anchor, 5 | confidence 낮으면 수동 보조, 자동 완전 복원 보장 없음 |

UV Weld는 seam 유지의 명시적 예외다. 사용자가 요청한 UV 연결 변경만 허용하고 전후 연결 정보를 Undo로 복원해야 한다. 일반 이동·Stack·Density는 이 예외를 사용하지 않는다.
