# LSY UV Repair — 기술 타당성 및 근거

조사일: 2026-10-13. 아래 API는 공개 문서에서 확인했다. **실제 3ds Max 호출·성능·드래그 검증은 수행하지 않았다.** 문서 연도가 혼재하므로 실제 지원 버전의 인터페이스와 서명을 V0에서 다시 대조한다. 문서에 없는 이름을 구현 API로 가정하지 않는다.

## 판정 체계

- D: 공개 문서에 API/동작 명시. 호스트에서 통과했다는 뜻은 아니다.
- P: 문서화된 기반을 조합한 설계 제안. 실험 필요.
- U: 요구에 맞는 공개 제어 경로를 이번 조사에서 확인하지 못함. 불가능하다는 증명은 아니다.

## API 근거표

| ID | 확인한 API/속성 | 실제 의미와 한계 | 출처 |
|---|---|---|---|
| A01 | `setTickSize`, `setHitSize`, `setSelectionColor`, `setLineColor`, `setOpenEdgeColor`, `setFreeFormColor`, `setFillMode` | Tick은 **선택 점 크기**, Hit은 클릭 판정 크기다. 비선택 점 독립 크기/색상·Hover API로 확대 해석하지 않는다. D | [Preferences](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-99222CE9-9679-4879-BCB9-C1338AEE9A75.html) |
| A02 | `move`, `moveH`, `moveV`, `rotate`, `scale`, `scaleH`, `scaleV`, `setFreeFormMode` | 툴바 명령/Freeform 활성화. 네이티브 마우스 처리 자체를 교체하는 API가 아니다. D | [Main Toolbar](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-BE11A0A8-4280-46B4-ACAE-840CB96DB763.html) |
| A03 | `getSelectedVertices`, `selectVertices`, `getSelectedEdges`, `selectEdges`, `getSelectedFaces`, `selectFaces`; `getSelCenter`, `snapPivot`, `setPivotOffset`, `setResetPivotOnSelection`, `setAllowSelectionInsideGizmo` | 선택·피벗 제어. `snapPivot 1`은 중앙. 좌표 공간·선택 변경 시 피벗 수명은 실험한다. D | [Select and Transform](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-496CE46A-EBD3-40C2-9637-3F21E0F0B0FB.html) |
| A04 | `numberPolygonsByNode`, `numberPointsInFaceByNode`, `getVertexIndexFromFaceByNode`, `getVertexGeomIndexFromFaceByNode`, `GetVertexPositionByNode`, `setVertexPositionByNode` | Face corner를 통해 UV/geometry 대응을 읽는다. `unwrap6`의 node 명시형. seam은 좌표가 아닌 인덱스 연결로 판단한다. D | [Topology Editing](https://help.autodesk.com/cloudhelp/2019/ENU/3DSMax-MAXScript/files/GUID-E40598B1-859E-4E30-A2DB-93E6F80A2226.htm) |
| A05 | `setVertexPosition2(time,index,pos,hold,update)` | hold/update 제어를 제공하지만 다중 node·드래그 Undo 특성은 별도 검증. D | [Select and Transform](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-496CE46A-EBD3-40C2-9637-3F21E0F0B0FB.html) |
| A06 | `addMap`, `SetCurrentMap`, `setShowMap`, `updateMap`, `setAutoBackground` | 배경 맵 등록/선택/표시. AutoBackground는 재질 필터와 연동되며 Base Color 의미론까지 보장하지 않는다. D | [Main Toolbar](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-BE11A0A8-4280-46B4-ACAE-840CB96DB763.html) |
| A07 | `getMatID`, `setMatID`, `numberMatIDs` | Editor 필터 목록의 인덱스다. Face에 할당된 실제 Material ID를 곧바로 넘기지 않는다. D | [Edit UVWs Floater](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-A182EFF2-5FE1-4B2D-AC4E-DB3DB48136E9.html) |
| A08 | `MultiMaterial.materialIDList`, `.materialList` | ID와 슬롯의 대응을 명시적으로 찾는다. `.numsubs`는 유효 재질 수와 같지 않을 수 있다. D | [MultiMaterial](https://help.autodesk.com/cloudhelp/2021/ENU/3DSMax-MAXScript/files/GUID-7ECB1E85-6199-4143-BEDA-3B26DD35E0C3.htm) |
| A09 | `polyop.getFaceMatID` | Editable Poly의 Face ID 조회. 중간 Unwrap 면 인덱스를 base object에 그대로 사용해서는 안 된다. D | [Autodesk Editable Poly 예제](https://help.autodesk.com/cloudhelp/2027/ENU/MAXScript-Help/files/Frequently-Asked-Questions/Practical-Questions/Working-with-Editable-Polys/GUID-F3FDF49D-C48B-4B2D-BD4B-8DBCDE39081A.html) |
| A10 | `getNumSubMtls`, `getSubMtl`, `getNumSubTexmaps`, `getSubTexmap`, `getSubTexmapSlotName` | 그래프 탐색 가능. 슬롯 문자열만으로 Base Color를 확정하지 않는다. D | [Material common methods](https://help.autodesk.com/cloudhelp/2018/ENU/MAXScript-Help/files/GUID-23A6A316-7C51-430C-8A44-9236C837DB10.htm) |
| A11 | `Physical_Material.base_color_map`, `.base_color_map_on` | Physical 재질의 의미가 명확한 진입점. D | [Physical Material](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Material-MAXWrapper/Material-Types/GUID-57562F6A-A8A1-4A28-BAE1-0D4729411214.html) |
| A12 | `Standard.diffuseMap`, `.diffuseMapEnable`; `BitmapTexture.filename` | Standard Diffuse와 일반 Bitmap 파일. 다른 렌더러의 bitmap 클래스에는 별도 어댑터 필요. D | [Standard](https://help.autodesk.com/cloudhelp/2016/ENU/MAXScript-Help/files/GUID-57F5EBBA-5F54-4CD4-8993-0B07A3571293.htm), [BitmapTexture](https://help.autodesk.com/cloudhelp/2018/ENU/MAXScript-Help/files/GUID-A3231AD9-2FCB-483B-9F43-3914BD1CE3D6.htm) |
| A13 | `getMapChannel`, `setMapChannel`, `selectByMatID` | 구형 호환 규칙상 get은 UV 채널 1에 대해 0 반환, 1은 Vertex Colors 표기. set/get을 대칭이라고 가정하지 않는다. D | [Command Panel](https://help.autodesk.com/cloudhelp/2025/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-830F23A3-E594-476D-B531-631BCD72EB42.html) |
| A14 | `pymxs.undo`, `pymxs.run_undo`, `pymxs.run_redo`, `pymxs.byref` | undo 블록 안의 예외는 롤백 후 바깥으로 전파되지 않을 수 있다. 성공 여부를 별도 기록한다. D | [pymxs module](https://help.autodesk.com/cloudhelp/2022/ENU/Max-Python-API/using_pymxs/pymxs_module.html) |
| A15 | `theHold.Begin`, `Accept`, `Cancel`, `Holding` | 이벤트에 걸친 드래그 트랜잭션 후보. setter가 복구 데이터를 등록하는지 실험해야 한다. D/P | [theHold](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/MAXScript-Tools-and-Interaction/Miscellaneous-Functions/GUID-17BFEAAF-3395-4FFB-9F98-54767481AB08.html) |
| A16 | `QGraphicsView`, `mapToScene`, `mapFromScene`, mouse event overrides | 자체 2D 화면·마우스 입력 기반. UV 데이터 쓰기와 기즈모 수학은 자체 구현. D/P | [Qt QGraphicsView](https://doc.qt.io/qtforpython-6.8/PySide6/QtWidgets/QGraphicsView.html) |
| A17 | `getAreaByNode`, `setFaceVertex`, `forceUpdate` | 면적은 참고 교차검산용. `setFaceVertex`는 공유 점 분리 가능, `forceUpdate true`는 토폴로지 변경 시 mapping reset 가능. 일반 이동/새로고침에 사용하지 않는다. D | [Topology Editing](https://help.autodesk.com/cloudhelp/2019/ENU/3DSMax-MAXScript/files/GUID-E40598B1-859E-4E30-A2DB-93E6F80A2226.htm) |

`setVertexPositionByNode(time,index,pos,node)`와 A05는 서명이 다르다. A05의 hold/update 인수를 node형에 임의 추가하지 않는다. A17 문서에는 면적과 bounding rectangle 설명의 중복 이름이 있으므로 by-reference 호출은 실제 인터페이스 조회 후 확정한다.

## 네이티브 가시성·기즈모 판단

| 요구 | 네이티브 근거 | 판정/대안 |
|---|---|---|
| 선택 점 크기·색, edge/seam 색 | A01 | D, DPI/대비 실험 필요 |
| 비선택 점의 독립 크기·색 | 직접 전용 API 미확인 | U, Max 색상 설정의 영향 조사 후 부족하면 custom |
| Hover 점 강조 | 공개 pointer hit-test/overlay hook 미확인 | U, custom hit-testing으로 구현 |
| Island 구분 | 선택 face fill/edge 표시 활용 가능 | P, 임의 아일랜드별 색·Hover는 custom 후보 |
| M/R/S·피벗·축 제한 | A02/A03 | D, 실제 드래그 Test A로 검증 |
| 간헐적 기즈모 소실 복구 보장 | 전용 보장 API 미확인 | U, 재현·상태 정합성 검증 후 전환 |
| 커스텀 2D 기즈모 | A16 + A04/A15 | P, 입력·실시간 쓰기·Undo가 함께 통과해야 완료 |

네이티브 PoC에서는 Modify context, 대상 modifier, UV 선택 모드, Freeform 여부, selection lock, soft selection, pivot, 편집창 포커스/재개방을 각각 분리해 재현한다. 3D 투영 gizmo나 `ZoomToGizmo`를 UV 변환 gizmo 제어로 오인하지 않는다. 키보드/윈도 메시지 자동 클릭이나 비공개 UI 내부 핸들 의존은 출시 경로로 채택하지 않는다.

## 기존 도구의 공개 기능 분석

제품명 UV Tools는 동명 자료가 있어 **HQ Details의 UV Tools**로 특정했다. 다른 제품을 의미한다면 비교 대상만 다시 확인한다. 기능 설명은 내부 알고리즘·재사용 라이선스·현재 Max 호환성의 증거가 아니다.

| 도구·공개 근거 | 확인한 기능 | LSY에 반영할 점 | 확인되지 않은 점 |
|---|---|---|---|
| [HQ Details UV Tools](https://hqdetails.com/shop/uvtools) | topology/geometry area 기반 similar, stack, TD get/set 계열, UDIM 관련 도구 | 작은 반복 작업을 패널로 제공하고 선택 결과를 검토하는 흐름 | 공개 Stack 설명은 위치 이동 후 회전·스케일 유지. F04의 완전 정합을 보장하는 근거로 쓰지 않음 |
| [PolyUnwrapper Selection](https://www.polytools3d.com/tools/polyunwrapper/help/04_selection_and_texture.html), [Scale](https://www.polytools3d.com/tools/polyunwrapper/help/07_scale.html), [Arrange](https://www.polytools3d.com/tools/polyunwrapper/help/08_arrange.html) | Shell 선택, 임시 checker, 밀도 정규화, packing | 선택 편의와 밀도 조작 UX 참고 | 기존 재질을 checker로 교체하는 흐름은 LSY 기본값에서 제외. 기즈모 소실 해결·정확한 similar/stack 알고리즘은 미확인 |
| [TexTools 저자 게시·변경 기록](https://scriptspot.com/3ds-max/scripts/textools-toolbox-for-the-texture-artist) | 저자 renderhjs가 TD read/apply, shell 이동/회전/스케일 stack, UV channel 지원을 설명 | reference density, 반복 shell 편집 참고 | 저자가 회전 대칭 shell의 stack 모호성을 언급. 오래된 기록이며 현재 버전 호환/정확도 보증 아님 |

TexTools 원 사이트는 이번 조회에서 본문을 확보하지 못해 저자가 직접 남긴 공개 기록을 사용했다. 다른 이용자의 댓글을 구현 근거로 채택하지 않았다. 어느 도구의 코드도 복사·디컴파일하지 않았고 설치·실행 비교도 하지 않았다.

## 핵심 기능별 구현 검증 카드

아래 모듈명은 **예상 코드 구조**일 뿐 생성된 파일이나 Autodesk API 이름이 아니다. 동작 명세는 FEATURE_SPEC, 수치 기준은 TEST_PLAN에 연결한다.

| 기능 | 구현 방법·필요 API | 구조 제안 | 난이도(1–5) | 주요 실패 | 최소 검증/완료 조건 |
|---|---|---|---|---|---|
| F01 | A01 설정 읽기/적용·복원; 미지원 표시는 A16 렌더러 | VisibilitySettings, NativeEditorAdapter, CanvasRenderer | native 2 / custom 3 | 선택 점만 커짐, DPI hit 영역 불일치 | 크기/색/Hover/edge/island 모든 옵션 확인, Test A 보조 조건 통과 |
| F02 | A02/A03 네이티브 상태; custom A04/A15/A16 | SelectionModel, GizmoController, UVTransaction | native 3 / custom 5 | 무기즈모, pivot jump, Undo 분할, 포커스 상실 | Test A/F 통과, 1 drag=1 Undo, Esc 완전 복구 |
| F03 | A04 연결 그래프 → 후보 필터 → 대응·정합 잔차 계산; A03 선택 | IslandGraph, SimilarityEngine | exact 4 / approximate 5 | bbox 충돌, 대칭·구멍·서로 다른 연결 오검출 | Test B, 음성 대조 0개 오선택, 근사 오차 표시 |
| F04 | F03 대응 → 제약된 2D 정합 → preview → A04 좌표 쓰기/A14 | Correspondence, StackSolver, StackCommand | 5 | mirror 오적용, texture 다른 영역 손상 | Test C/F, reference 불변, 허용오차 밖은 적용 차단 |
| F05 | 같은 corner triangulation의 3D/UV 면적; A04/A17 교차검산; A14 | DensityCalculator, UnitContext, DensityCommand | 3–4 | 단위·비균일 스케일·해상도 오류 | Test D/F, 수식 기준 오차 0.1% 이내 |
| F06 | A09 face ID → A08 슬롯 → A10–A12 의미론 탐색 → A06 | MaterialResolver, TextureResolver, BackgroundController | 4 | sparse ID, 잘못된 bitmap, 오래된 async 결과 | Test E/F, ID·채널 분리, 혼합 선택·고정 정책 통과 |

## 런타임·성능·SDK 한계

Autodesk의 버전 표는 Max 2024 Python 3.10.8, Max 2025 Python 3.11.4/PySide 6.5.3, 2025.1 Python 3.11.8을 제시한다. 일반 소개 페이지에는 예전 Python/PySide 설명과 새 설명이 함께 있으므로 버전 표와 실제 호스트 조회를 우선한다. 이후 버전의 런타임을 추정하여 고정하지 않는다. [Python 변경 내역](https://help.autodesk.com/cloudhelp/2025/ENU/MAXDEV-Python/files/MAXDEV_Python_what_s_new_in_3ds_max_python_api_html.html), [Python 개요](https://help.autodesk.com/cloudhelp/2025/ENU/MAXDEV-Python/files/MAXDEV_Python_about_the_3ds_max_python_api_html.html).

Max API 접근·씬 쓰기는 메인 스레드로 제한하는 설계다. worker는 복사된 숫자 배열만 분석한다. 점별 Python↔MAXScript 호출이 병목이면 먼저 MAXScript 내부 일괄 루프, 변경 점만 쓰기, 화면 갱신 병합을 실험한다. [pymxs threading 제약](https://help.autodesk.com/cloudhelp/2022/ENU/Max-Python-API/using_pymxs/pymxs_module.html).

SDK 도입은 측정된 병목이나 스크립트 setter의 Undo 한계가 남을 때 결정한다. 직접 modifier 데이터를 다루면 RestoreObj 등 호스트 Undo 통합과 버전별 빌드가 추가된다. SDK가 네이티브 UV 화면의 임의 overlay나 소실 문제를 해결한다고 단정하지 않는다. [SDK Undo 요구](https://help.autodesk.com/cloudhelp/2023/ENU/Max-Developer-Help/3ds_max_sdk_features/the_undo_and_redo_system/how_to_enable_undo_and_redo.html).

## 결론과 미해결 게이트

F01 일부, UV 읽기/쓰기, 피벗·배경 선택은 D. F03–F06의 제품 수준 조합은 P. F01 전체와 F02 안정성은 Max 실험 전 미확정이다. V0에서 실제 드래그·Undo·평가 단계 Face 대응·재질 탐색을 먼저 검증한다. 이 네 항목 중 하나라도 실패하면 기능 확장보다 어댑터/편집 화면 설계를 먼저 수정한다.
