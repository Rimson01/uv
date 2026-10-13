# V0 실행 가이드 — 3ds Max 2023 / 2025

이 폴더에는 **검증용 스크립트**가 있다. 3ds Max용 제품 설치 프로그램이나 V1 UV 편집기가 아니다. 집의 2025에서 먼저 실행하고 회사의 2023에서 같은 순서로 검사한다. 두 버전의 결과를 별도 파일로 저장한다. 준비와 실행에 Qt 설치는 필요 없다. 패널은 MAXScript rollout으로 만들어져 PySide2/6 차이를 피한다.

## 파일

| 파일 | 용도 | 장면 변경 |
|---|---|---|
| `LSY_UV_V0.ms` | native 점 표시/기즈모 버튼, 선택 UV 전후 비교, 재질 ID 조회, 결과 기록 | 선택한 Unwrap의 표시 설정과 native 도구 모드만 변경. UV·geometry·재질에는 스크립트가 쓰지 않음 |
| `v0_runtime_probe.py` | 실제 호스트 Python/Qt/Max 버전 JSON | 없음 |
| `v0_math_probe.py` | 37° 회전 정합과 밀도 공식의 독립 계산 | 없음 |

## 준비

1. 테스트할 `.max` 파일을 **복사하여 새 이름으로 저장**한다. 간단한 Editable Poly에 Unwrap UVW modifier가 있고, 재질 텍스처가 보이는 씬이 좋다. P3에는 Editable Poly base + Unwrap 하나만 있는 별도 테스트 씬을 사용한다.
2. UV 편집 대상 오브젝트 하나를 선택한다. Modify 패널에서 검사할 Unwrap UVW를 활성화한다. 같은 오브젝트에 Unwrap이 여러 개라면 반드시 원하는 modifier를 패널에서 클릭한다.
3. 3ds Max 메뉴 **Scripting → Run Script**에서 `LSY_UV_V0.ms`를 연다. 패널이 뜨면 `P0 Diagnose selected object`를 누른다. UV Editor는 Modify 패널의 **Open UV Editor** 버튼으로 직접 연다.
4. Max의 **Python Editor**에서 `v0_runtime_probe.py`를 실행한다. 실행 후 출력되는 `LSY_UV_V0_runtime.json` 경로를 기록한다. 기본 저장 위치는 Windows 임시 폴더다. Python/Qt 진단은 호스트에서 실행해야 정확하다.

MAXScript 패널을 다시 실행하면 이전 패널을 닫고 이전에 적용한 표시 설정을 복원하려고 시도한다. 명시적인 `Restore original settings` 버튼으로 복원한 뒤 닫는 것이 가장 확실하다. 장면을 저장하기 전 원래 색/점 크기를 확인한다.

## 테스트 순서

| 단계 | 실행 | 보고서에 기록할 값 |
|---|---|---|
| P0 | 진단 버튼 + Python probe | Max build, Python/Qt, UV 채널, 점/면 수, 선택 모드, API 오류 |
| P1 가시성 | 선택 점 크기·Hit size·색/edge 색 적용, 다시 복원 | 선택/비선택 점·Hover·아일랜드 강조가 충분한지. `setTickSize`는 선택 점에만 적용될 수 있음 |
| P1 기즈모 | UV 점 선택 후 Freeform ON, Move/Rotate/Scale 및 U/V 버튼을 누르고 **실제 마우스 드래그** | 핸들을 잡을 수 있는지, 이동 중 3D 뷰 갱신, pivot, 선택 변경/포커스/재개방 때 소실 여부 |
| P2 | `Capture selected UVs` → native drag → `Compare after drag` → **UV Editor 다시 활성화** → Ctrl+Z → `Compare after Undo` → **UV Editor 다시 활성화** → Ctrl+Y → `Compare after Redo` | 원래 좌표와 드래그 직후 좌표 각각에 대한 오차, 선택 점 수. 비교 버튼은 Undo/Redo를 실행하지 않음 |
| P3 | 단순 테스트 씬에서 Face 모드로 ID 1/2/3 선택 → `Inspect selected UV faces` | face별 실제 ID, Multi/Sub slot, Base Color/Diffuse Bitmap 경로. 2/7/42도 검사 |
| P4 | 일반 Python 또는 Max Python에서 `v0_math_probe.py` 실행 | 양성/음성 shape와 1024²/2048×1024 밀도 계산 PASS |

P1의 드래그는 UV Editor에서 사람 손으로 해야 한다. 패널의 화살표/모드 버튼 클릭은 기즈모 테스트 성공의 증거가 아니다. P2는 캡처한 UV 점 **좌표만** 비교한다. 일부 점만 바뀌면 클릭 때 선택 상태가 달라졌는지 확인한다. geometry·seam·다른 채널 불변, 정확한 Undo 항목 수는 이 도구가 자동 판정하지 않으므로 Test F에 따라 수동 검사하고 결과 Note에 적는다.

Move·Rotate·Scale 등 모드를 바꾸면 이전 P2 캡처가 폐기된다. **각 모드를 선택한 다음 새로 Capture**하고 drag → Undo → Redo를 한 번씩 실행한다. Redo 비교를 마친 뒤 다음 테스트도 새로 Capture한다.

각 단계 후 드롭다운에서 해당 Step을 선택하고 Note에 재현 조건·성공/실패 증상을 쓴 뒤 PASS/FAIL/SKIP을 기록한다. 마지막에 **Save report**로 `.txt`를 저장한다. 집/회사 파일명을 각각 `v0_home_2025.txt`, `v0_work_2023.txt`처럼 구분한다. 회사 자산명·텍스처 경로가 들어갈 수 있으니 회사 데이터가 들어간 보고서는 공개 GitHub에 올리지 않는다.

## 판정 기준과 제한

- P1 기즈모: 실제 M/R/S 손잡이가 선택 변경·창 재개방을 포함해 반복 드래그에서 나타나고 작동해야 한다. 1회 성공으로 V1 완료로 판단하지 않는다. [전체 Test A](../TEST_PLAN.md)를 참고한다.
- P2: drag 후 원래 좌표와의 delta > 0, Undo 후 원래 좌표와의 delta ≤1e-6, Redo 후 **드래그 직후 좌표**와의 delta ≤1e-6. Undo/Redo 명령은 UV Editor에 포커스를 두고 직접 실행한다.
- P3: 간단한 단일 Unwrap 스택만 자동 조회한다. 중간 modifier 또는 복잡한 렌더러 재질에서는 잘못된 face 대응을 피하려고 판정을 중단한다. 중첩/절차형 texture는 후보가 없는 것으로 표시한다.
- P4: 알고리즘과 숫자 공식의 최소 예시만 검증한다. 실제 Max UV topology 추출·50k 성능은 별도의 실사용 측정이 필요하다.
- 2023/2025에서 결과가 다르면 두 보고서와 정확한 Max update build를 보존한다. 호스트를 직접 실행하지 않은 상태의 결과는 `Not Run`이다.

이 작업 환경에서 확인된 Max Batch는 2024 버전이다. Batch 시작이 종료 코드 1로 끝나 패널 로딩 검사까지 도달하지 못했다. 따라서 패널의 MAXScript 문법·화면 동작과 2023/2025 호환성은 현재 **미검증**이다. 실제 두 호스트에서 첫 실행 시 Listener의 오류 메시지까지 보고서에 기록한다.

## 문서 근거

패널에서 사용한 점/선 설정은 [Autodesk Preferences](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-99222CE9-9679-4879-BCB9-C1338AEE9A75.html), native M/R/S·Freeform은 [Main Toolbar](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-BE11A0A8-4280-46B4-ACAE-840CB96DB763.html), UV 선택/좌표는 [Select and Transform](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-496CE46A-EBD3-40C2-9637-3F21E0F0B0FB.html)에 근거한다. 프로그램에서 어떤 call이 실제로 성공하는지는 P0 로그로 검증한다.
