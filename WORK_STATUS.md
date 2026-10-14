# LSY UV Repair 현재 상태 — 2026-10-14 / 0.14.1 적용 오류·native Density 수정본

이 문서는 현재 판정이다. 상세 발견·변경은 [전체 리뷰](REVIEW_2026-10-14.md), 다음 순서는 [로드맵](IMPLEMENTATION_ROADMAP.md)을 따른다. 버튼 존재와 cloud 검사 통과를 제품 완료로 세지 않는다.

## 구현·검증 상태

| 요구 | 구현 상태 | 실제 사용자 Max 증거 | 남은 범위 |
|---|---|---|---|
| F01 점 가시성 | 선택 점 크기/색과 UV 선 옵션 | 선택 점 색 동작 확인 | native 미선택 점 독립 표시·hover 보류. 별도 canvas 폐기 |
| F02 변환 | native M/R/S·축·pivot 호출, 보조 numeric 도구 | native drag 일부 Undo/Redo PASS | numeric Undo/rollback·선택 오류·lifecycle·전체 stress 미검증 |
| F03 유사 섬 | geometry edge+UV endpoint islands, 같은 ID 회전+이동 Exact 검색, 명시 후보 면 선택 | 0.11.2 검색·결과 선택 확인 | correspondence·rigid transform 저장 추가. 대칭 anchor, 취소/규모, Approximate/scale/mirror 미완 |
| F04 Stack | Exact 대응 기반 회전+이동 계획·적용 코드. 기준 불변·공통 Hold/rollback | 최신 코드 host 미실행 | ghost 시각 preview 없음. 수치 검토 단계만 제공. 실제 Apply/Undo/rollback gate 미완 |
| F05 Density | Get/Reference/Set 계산·적용 코드, native evaluated mesh 삼각분할·world cm·입력 W/H | CPU 면적/단위 fixture PASS. host 미실행 | raw uniform resolution 한정, native corner 대응 검증, ghost preview·host Undo 검증 미완 |
| F06 재질 배경 | Bitmap/sparse Multi/Sub, base/albedo 의미 슬롯, manual/lock/auto·복원 코드 | 이전 버전 Bitmap 배경 전환 확인 | PBR 실모델·최신 map 경로 미검증. ID+배경 연동은 사용자 실패 확인, 미해결 |

현재 지원 한도는 단일 Editable Poly + Unwrap 하나의 제한된 경로다. Exact는 128점/섬, 분석 20,000면/100,000UV점, anchor/시간 제한. 다중 node, full modifier stack, animation, Approximate, 다른 topology 복원은 제품 지원이 아니다.

## 이번 전체 리뷰에서 수정

- 검색·기준 재지정 실패 후 이전 분석 결과 사용 방지; bind/reload/close에서 세션 초기화.
- snapshot root material identity와 W 유효성 검사.
- numeric 쓰기 전 Auto Key/Soft Selection/animated modifier/외부 Hold/공유 base 검사.
- UV 점 수 변화 시 이전 인덱스 복원 쓰기 중단. 0.14는 전체 face corner/geometry index 동일성 검사와 공통 Hold/Cancel 추가.
- Exact 내부 deadline 검사 보강.
- 실패 확인된 ID 연동 기본 해제와 실험 상태 설명; `ID 필터 복원` 이름 수정; native 도구 기본 접기.
- host regression catch 재throw 구문 수정.

외부 map 변경 cache invalidation과 타이머 중복 진입 방지는 유지한다. 0.14는 Editor 준비 상태를 먼저 검사하고, ID 조회 실패가 자동 배경을 중단하지 않도록 분리했다.

## 미해결 중요 사항

1. 실제 native ID/texture UI 발견 실패. 숫자 getter 변경은 시각 필터 성공 근거가 아니다.
2. ID/auto/map 복원 순서와 pending 복원 기록에 대한 재시도 구조 부족.
3. 전체 UV topology revision과 모든 animated controller 검사·Undo 오염 방지는 host gate 미완.
4. Exact/Stack/Density의 최신 Max 실행 및 실패 주입·Undo 검증이 남음.
5. F04/F05의 수치 검토·적용은 구현됐지만 원래 계획의 ghost 시각 preview는 미구현.

## 검증 범위

Linux cloud에서 CPU 수학/그래프, source 계약, Python 구문, single-file BOM 빌드를 검사한다. 3ds Max/MS 컴파일, C# bridge, native UI, 쓰기·Undo는 실행하지 못한다. 사용자 보고의 버전/경로만 host evidence로 취급하며 최신 수정본에 자동 승계하지 않는다.

이번 수정본 검증: 자동 검사 69개 PASS, Python source 구문 및 MXS 괄호/문자열 제거 후 delimiter 검사 PASS, standalone BOM export 생성. MXS delimiter 검사는 Max 컴파일 검사와 다르다. C#/기존 Qt helper도 canonical 소스와 단독 파일의 내장 문자열이 같도록 빌드 검사를 보강했다.

### 0.13.1 — texture preflight 순서 수정

사용자 0.13에서 `Native texture UI matches=0`를 다시 보고했다. 자동 배경의 read-only preflight가 현재 필터로 줄어든 목록을 reset 이전에 검사하던 순서를 수정했다. ID UI preflight는 유지하되, texture 검사는 All IDs/native auto off 처리 후, map 등록/선택 전에 진행한다. 실패 시 해당 reset의 filter/auto ownership 복원을 시도한다. 신규 로그에 실제 filter, auto, maps, texture-list, current-map 값을 추가했다. 이 오류가 반드시 필터 때문에 발생했다는 증거는 없으므로 남은 목록 인식 문제를 해결 완료로 집계하지 않는다.


## 0.14 검증과 배경 회귀 수정

- 사용자 로그의 maps=-6은 정상 map count가 아니다. control counts가 양수가 될 때까지 배경/ID UI 호출을 대기한다. Face 자동도 edit 직후 즉시 호출하지 않고 다음 tick에서 처리한다.
- All IDs API index=0 가정을 제거하고 1로 수정했다. 근거와 버전 한계는 v1/BACKGROUND_FINDINGS.md 참조.
- ID UI 실패는 실험 ID 연동만 끄고 배경을 계속한다. 실제 native ID 화면 필터링 완료로 집계하지 않는다.
- Numeric/Stack/Density는 하나의 동기 Hold를 사용하며 전체 UV 좌표와 corner mapping을 검증한다. 취소 뒤 복원이 안 됐으면 topology가 같을 때만 fallback 복원, 실패 시 대상 쓰기 차단.
- Density는 입력 해상도를 모든 대상에 동일 적용하는 Raw UV px/cm다. geometry world 좌표를 시스템 단위에서 cm로 변환한다. 평면 단순 N-gon ear clipping은 UV와 같은 corner triangles를 공유한다. 256 corners/face, geometry 200,000 points, 계산 5초 한도. renderer/UDIM별 effective density는 미지원.
- 자동 검사 82개 PASS. 실제 Max 컴파일/새 Hold·Undo/최신 배경 복구는 미실행. 단독 `.ms` 안에 필요한 Python/MS helper를 포함한다.

## 0.14.1 — 사용자 전체 로그 반영

새 host 증거: 0.14의 Exact 검색·후보 선택, Density 조회·참조 복사·변경 계산이 실행됐다. 숫자 정확도·Apply/Undo 성공은 아직 확인되지 않았다. 로그에서 map count는 14, texture-list는 13으로 정상 범위였지만 실제 ID UI 발견은 실패했다. 자동 배경 표시 성공은 이 로그만으로 확정하지 않는다.

수정:
- Unwrap modifier에 직접 `isAnimated`를 호출하면 지원되지 않는다. modifier sub-animation에서 controller를 찾아 controller에만 검사한다. 열거 오류를 무시해 검사를 우회하지 않는다.
- Density는 원본 변환 없이 `snapshotAsMesh`의 실제 triangles를 수집한다. geometry index/face 대응과 evaluated UV corner를 검증하고 geometry와 UV에 같은 삼각형을 적용한다. native triangles가 제공된 host 경로에서는 non-planar 단순 polygon을 처리할 수 있다. 모호한 대응/바뀐 vertex indexing은 거절한다. apply 전 재삼각화·geometry 변경을 재검사한다.
- world 좌표에 objectTransform을 사용해 pivot object-offset transform도 포함한다.
- SDK 샘플의 setter가 hold=true로 자체 Begin/Accept를 한다는 점을 반영해 외부 단일 Hold 안에서 반복하지 않는다. SuperBegin/SuperAccept로 native Undo들을 한 그룹에 묶고, 실패하면 SuperCancel한다. update=true는 마지막 setter에서만 요청한다. 실제 Max에서 한 번 Undo/Redo로 전체 복원되는지는 아직 미실행이다.
- legacy native Undo snapshot의 메모리 비용을 제한하기 위해 `전체 UV 점 수 × 변경 점 수 <= 2,000,000`의 임시 budget을 적용한다. 제한 초과 시 쓰기 전 거절하며 선택을 줄여야 한다. 지원 규모는 host profile 후 재산정한다.
- 적용 버튼은 유효한 계산 계획이 있을 때만 활성화한다. Reference 복사는 목표 숫자를 채우는 작업이며 적용 계획을 만들지는 않는다.

자동 검사 86개 PASS. native controller dispatch와 actual triangle extraction/SuperHold의 최신 host 검증은 별도로 남는다. ID 표시 UI 발견과 ghost preview는 이 patch에서 완료로 집계하지 않는다.

## 0.14.4 — 대칭 후보 정책·메시 좌표계

사용자 로그에서 Exact 0 / 대칭 5 / 나머지 0이 확인됐다. 데이터 불일치가 아니라 기본 모호성 제외 정책으로 Stack이 차단됐다. `대칭 후보: 회전 없이 맞춤`을 명시적으로 켜고 다시 검색하면, 회전 0 대응이 정확히 하나이고 translation-only 잔차가 기준 이내인 후보만 허용한다. 실제 계산 fit은 cos=1/sin=0으로 고정한다. 기본 체크 해제이며 회전이 필요한 대칭 후보는 계속 제외한다.

Density의 base=[-2703.35,-4295.05,0], evaluated=[-113089,216436,0]은 좌표 mismatch 증거이며 index reorder 증거가 아니다. 평가 메시 좌표를 identity / inverse objectTransform / inverse node.transform로 각각 변환하고 모든 정점이 base와 같은 순서로 맞는 경우에만 대응을 승인한다. 변환 후 float 정밀도 허용치를 적용하며 개별 정점 nearest remap은 하지 않는다. UV corner 검증도 유지한다. 모든 후보가 실패하면 읽기 오류로 멈춘다. 최신 Max 실행 결과는 아직 없다.

자동 검사 90개 PASS. 파일 `LSY_UV_Workbench_v0144_fix.ms` 하나로 배포한다. 실제 밀도 복구·대칭 Stack Apply/Undo는 호스트 검증 대기다.

## 0.15 — Stack / Density 독립 UI·계산

사용자 Max 로그로 0.14.4의 Exact 3 후보, 18점 Stack 적용이 반복 통과했다. 실제 Ctrl+Z/Redo 결과는 로그에 없으므로 Undo/Redo gate 통과로 확정하지 않는다. Density의 전체 좌표 검증은 실패했다.

평가 mesh 정점 추출은 standalone mesh 값에 대해 node 인수 없이 meshop.getVert를 사용하도록 변경했다. 일반 getVert의 현재 node/reference 좌표계 의존 경로를 제외하고, 전체 정점 변환 검증 및 UV corner 검증은 유지한다. 이 변경의 실제 Density 성공은 아직 미확인이다.

사용자 요청에 따라 Exact Stack / Texel Density를 별도 rollout으로 분리했다. 해상도, 계획 배열, 조회/계산/적용/취소 버튼이 각자 독립이다. F03 검색/기준 재지정과 Density 조회·참조 복사 같은 읽기 작업은 다른 도구의 계획을 폐기하지 않는다. 실제 UV 쓰기나 bind/close는 공통 snapshot 기준에 따라 두 계획을 무효화한다. 공통 native Undo·복원 엔진만 공유한다.

자동 검사 94개 PASS. 배포 파일 LSY_UV_Workbench_v015.ms. 분리 UI와 Density raw mesh getter는 Max host 미검증이다.

## 0.15.1 — 실제 적용 결과와 밀도 오류 처리

사용자 Max 2023 로그에서 inverse objectTransform 정점 오차 0.00100708로 Density 조회/계산 및 37점 적용, Exact 3 후보의 18점 Stack 적용을 확인했다. 실제 Undo/Redo 성공은 확인되지 않았다. Stack과 Density는 별도 패널/해상도/계획으로 유지한다.

- UV 삼각형 면적이 0이라는 이유만으로 유효한 섬 전체를 거절하지 않는다. 총 면적으로 계산하며 경고한다. 정의 불가능한 섬은 면/삼각형별 사유와 N/A를 표시하고 나머지 섬은 조회한다. N/A 포함 참조 복사와 변경 적용 계획은 차단한다.
- 평가 mesh 대응은 실제 면에서 쓰이는 정점을 모두 검증한다. 큰 월드 위치의 Float32 변환 오차 허용치를 입력 크기에 맞추고, 실패 시 좌표계별 최대 오차/최악 정점 정보를 제공한다. 임의 nearest index 대응은 하지 않는다.
- Density 면적 좌표에서 공통 월드 translation을 제외해 작은 면의 정밀도 손실을 줄인다. 선형 objectTransform과 cm 변환은 유지하며 node transform은 변경하지 않는다.
- 보류 배경 복원은 동일한 활성 modifier의 목록 대응이 확인될 때 재시도한다. 외부 변경은 보존한다. 실제 자동 ID 필터 연동은 미완료다.

자동 검사 100개 PASS. 배포 파일 LSY_UV_Workbench_v0151.ms. 이 수정의 Max 컴파일, Density N/A 표시, 배경 복원 재시도 및 실제 Undo/Redo는 Linux에서 실행하지 못했다.

## 작업 종료 체크포인트 — 2026-10-14

사용자 요청으로 0.15.1을 현재 작업 마감/백업 버전으로 보관한다. 소스, 단독 실행 파일, 테스트, 원래 계획 및 리뷰/미완료 기록을 함께 저장한다. 다음 개발은 별도 요청 시 재개한다. 0.15.1의 Max 실행/Undo·Redo와 자동 ID 연동은 미확인 또는 미완료 상태로 유지한다.
