# LSY UV Workbench 0.15.1

기존 UV Editor를 사용하는 세로 보조 패널. 배경 회귀 수정과 Exact Stack / Texel Density 구현 후보를 함께 제공한다. 사용자 Max 2023 로그에서 0.15의 Stack 18점 및 Density 37점 적용이 확인됐다. 0.15.1 변경과 실제 Undo/Redo는 host 검증 대기다.

## 실행

`LSY_UV_Workbench_v0151.ms` 하나를 Scripting → Run Script로 실행한다. 활성 Unwrap을 선택하고 **대상 연결 → UV Editor → 면 자동**을 사용한다. Python 파일을 별도로 배치할 필요가 없다.

## 자동 배경 수정

이전 코드의 All IDs=0 가정을 1로 수정했다. `maps=-6`처럼 목록 개수가 음수이면 UI 준비가 안 된 것으로 처리하고, 상태를 더 변경하지 않고 기다린다. Editor가 준비되면 자동 처리를 재개한다. Face 자동은 `edit()` 직후 UI를 읽지 않고 다음 timer tick에서 처리한다.

ID UI 발견 실패는 실험 ID 체크만 끄고 배경-only 경로를 계속한다. 예외 내용이 복원 호출 과정에서 사라지지 않도록 보관하며 처리 단계를 기록한다. 원인 분석과 SDK 버전 한계는 [BACKGROUND_FINDINGS](BACKGROUND_FINDINGS.md)에 있다. 실제 ID 필터·배경 동시 연동의 시각 결과는 여전히 host 미확인이다.

## Exact Stack

1. 한 섬의 면/점을 선택 → **기준 섬 지정 → 유사 섬 검색**.
2. 별도 Exact Stack 섹션에서 이미지 **W/H** 입력.
3. **Exact Stack 계산** → 후보별 회전·이동·잔차 검토 → **계산한 변경 적용**.

동일 ID의 모호하지 않은 Exact 후보만 기준 섬에 회전+이동으로 겹친다. scale/mirror는 사용하지 않으며 기준 섬과 W/UV 연결을 쓰지 않는다. 기준에 직접 Bitmap이 해석되고 파일이 존재해야 한다. 공유 점으로 다른 섬에 영향을 주거나 잔차가 한도를 넘으면 거절한다.

계산은 좌표를 쓰지 않는다. 적용은 공통 Hold/Cancel 경로를 사용한다. **검토는 수치 단계이며 화면 ghost preview는 아직 없다.** 기존 텍스처 영역은 적용 후 달라질 수 있다. 원래 F04 출시 gate 전체 통과가 아니다.

## Texel Density

1. 대상 섬의 면 또는 점을 선택하고 실제 이미지 W/H 입력.
2. **밀도 조회**: 선택이 닿는 전체 섬별 px/cm와 전체 면적 기준 밀도 표시.
3. **참조 밀도 복사**: 현재 측정의 면적 기준 값을 목표 px/cm로 복사.
4. 대상을 선택하고 **밀도 변경 계산 → 계산한 변경 적용**.

각 섬의 bbox 중심에서 균일 확대/축소하며 W는 보존한다. 모든 대상에 입력 해상도를 동일 적용하는 **Raw UV density**다. world transform·시스템 단위·비정사각 이미지를 계산에 반영한다. 평가 mesh의 실제 삼각형을 원본 polygon corner에 대응시켜 geometry와 UV에 동일 적용한다. 비평면 polygon도 그 대응이 명확하면 처리한다. UV 면적이 0인 일부 삼각형은 섬의 총 면적으로 계산하며 경고한다. 밀도를 정의할 수 없는 섬은 N/A로 표시하고 다른 유효 섬은 조회한다. N/A를 포함한 변경 계산·참조 복사는 차단한다. 모호한 대응·변경된 vertex indexing은 거절한다. UV tiling/rotation/renderer/UDIM별 effective density는 미지원이다.

## 쓰기·검증 범위

단일 Editable Poly + Unwrap 하나. Auto Key, Soft Selection, animated modifier, 외부 Hold, 공유 base/modifier 상태에서는 좌표 쓰기를 막는다. 계획 이후 UV/topology/time/material/해상도 변경 시 재계산한다. Density는 world geometry/시스템 단위 변화도 확인한다.

Numeric/Stack/Density는 공통 SuperHold 그룹으로 적용한다. 전체 UV와 face corner mapping을 확인하고 실패 시 그룹을 취소한다. 복구 실패 후 topology가 다르면 이전 index에 쓰지 않는다. 실제 host의 Undo/Redo·실패 복원과 모든 animated controller 감지 범위는 아직 검증되지 않았다.

Exact: 128점/섬, 분석 20,000면/100,000UV점. Density: geometry 200,000점, evaluated mesh 400,000 triangles, 계산 5초 한도. 큰 모델에서 전체 snapshot 추출 시간은 별도로 host 측정해야 한다.

## 개발 검사

```sh
python3 -B -m unittest discover -s tests -q
python3 -B v1/build_release.py /workspace/exports/LSY_UV_Workbench_v0151.ms
```

100개 CPU/source/build 검사 통과. 단독 파일의 Python/C#/MS helper 일치와 BOM을 검증한다. Linux에서는 Max 컴파일/native UI/새 UV 쓰기·Undo를 실행하지 못했다. `tests/workbench_host_tests.ms`에 음수 map count와 저장된 37° Exact fit 검사도 포함했지만 host 미실행이다. 기존 exports는 덮어쓰지 않는다.

## 이전 0.14.1 수정 기록

최신 파일: `LSY_UV_Workbench_v0151.ms`.

사용자 로그에서 Density 조회/참조 복사/계산과 Exact 선택은 실행됐다. 적용은 modifier에 잘못 호출한 isAnimated 때문에 실패했다. 현재는 UV sub-animation의 controller를 검사한다. Density는 평가 mesh의 실제 삼각분할을 읽어 비평면 polygon을 처리하며, 원본 node를 convert/collapse하지 않는다. geometry/UV corner 대응이 명확한 경우만 지원한다.

native setter마다 내부 Hold를 사용하는 SDK 경로를 고려해 SuperHold로 전체 Undo를 묶었으며 마지막 점에서 화면 갱신을 요청한다. 최초 지원의 Undo 예산은 전체 UV 점 수 × 변경 점 수 2,000,000 이하다. 한 번 Undo·실패 복원·최신 컨트롤러 검사는 Max에서 아직 확인하지 못했다.

Reference 복사 뒤에는 **밀도 변경 계산**을 눌러야 적용할 수 있다. 계산 계획이 없는 동안 적용 버튼은 비활성이다. 자동 검사 86개 통과.


## 0.15 도구 분리

**Exact Stack**과 **Texel Density**는 서로 다른 섹션이다. 각각 독립적인 W/H, 계산 결과, 적용·취소 버튼을 사용한다. Density 조회/목표 숫자 변경이나 유사 섬 재검색으로 다른 도구의 읽기 계산을 지우지 않는다. 실제 좌표 적용 뒤에는 이전 좌표로 만든 다른 계산을 다시 해야 한다.

0.14.4 Stack 18점 적용은 사용자 Max에서 반복 확인됐다. 실제 Undo/Redo는 아직 미확인이다. Density getter를 standalone mesh의 raw `meshop.getVert` 경로로 수정했으며 전체 대응 검증은 유지했다. 최신 Density 실행과 분리 UI는 host 검증 대기다. 자동 검사 94개 통과.

## 0.15.1 밀도 오류 처리

큰 월드 위치에서 발생하는 Float32 좌표 오차를 변환 크기에 맞춰 검사한다. 실제 면에 쓰인 정점을 모두 검증하며, 실패하면 좌표계별 최대 오차와 해당 정점을 기록한다. 면적 계산에서 공통 월드 이동을 제외해 작은 삼각형의 정밀도 손실을 줄인다. scale/rotation/object-offset의 선형 변환은 유지한다.

퇴화 UV 삼각형이 포함돼도 섬 전체 면적이 유효하면 조회한다. 정의 불가능한 섬은 면/삼각형 번호와 원인을 N/A로 표시한다. 이 변경은 퇴화 UV를 자동으로 고치는 기능은 아니다.

목록 변경으로 보류했던 배경 복원은 같은 Unwrap이 활성화되고 목록 대응이 확인될 때 재시도한다. 외부 변경은 보존한다. 자동 ID 필터 연동은 여전히 미완료이며 기본 비활성이다.
