# LSY UV Repair — 프로젝트 개요

작성일: 2026-10-13 (Asia/Seoul). 상태: 개발 전 조사·설계 완료, Max 런타임 검증 전.

## 목적과 범위

게임 배경 에셋의 LOD 제작 중 Collapse, Remove, Weld, ProOptimizer 등으로 변형된 기존 UV를 **원래 텍스처를 보며 수동 복구**하는 3ds Max 도구다. 새 UV 자동 언랩, 자동 리패킹, 지오메트리 최적화가 주목적이 아니다. 최적화로 사라진 대응 정보를 원본 없이 완벽히 복원할 수 있다고 약속하지 않는다.

이번 산출물은 계획 문서 7개다. 실제 MAXScript/Python/C++ 코드, 설치 패키지, 테스트 씬은 만들지 않았다. 기존 프로젝트 파일은 변경하지 않았다. 실제 개발과 아래 PoC 실행은 별도 개발 착수 요청 이후 진행한다.

## 권장 결정

**Option B Hybrid를 기본 아키텍처로 채택하고, 네이티브 편집기를 먼저 검증한다.** Unwrap UVW를 UV 저장·평가·Undo 통합의 기반으로 유지하며 자체 패널에서 가시성 설정, 재질 탐색, 유사도·스택·밀도 기능을 제공한다. 이후 편집 화면은 다음 기준으로 정한다.

1. 네이티브 점 표시와 실제 기즈모 드래그가 F01/F02 요구 전체 및 Test A/F를 통과하면 네이티브 화면을 재사용한다.
2. 기즈모 재현 문제가 남거나 비선택 점 크기·Hover·아일랜드 강조 등 요구를 충족하지 못하면 **Option C의 PySide 커스텀 편집 화면**을 동일 데이터 계층에 연결한다. 현재 문서 조사만으로 네이티브 전체 충족을 확정할 수 없으므로 기준 예산에는 이 경로를 포함한다.
3. 네이티브 기능만으로 일부 요구를 제외한 제품을 만드는 것은 축소판이다. 전체 V1 완료로 판정하지 않으며 범위 변경을 별도로 합의한다.

선택 점 크기와 색상은 공개 API로 제어 가능하다. Freeform 모드와 피벗 API도 있지만, 존재 자체가 간헐적인 기즈모 소실 해결을 보증하지 않는다. [Autodesk Preferences](https://help.autodesk.com/cloudhelp/2024/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-99222CE9-9679-4879-BCB9-C1338AEE9A75.html), [Main Toolbar](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-BE11A0A8-4280-46B4-ACAE-840CB96DB763.html).

## 사용자 흐름

1. 최적화된 에셋을 선택하고 대상 Unwrap modifier와 UV Map Channel을 명시한다.
2. 현재 UV·토폴로지·재질 연결 상태를 읽고 편집 세션을 연다.
3. 선택 Face의 Material ID에 연결된 Base Color/Diffuse를 배경에 표시한다.
4. Vertex/Edge/Island를 선택하여 Move/Rotate/Scale 기즈모로 복구한다.
5. 필요할 때만 Similar → 대응 미리보기 → Stack을 적용한다.
6. 밀도·겹침·왜곡을 검사하고 Undo/Redo 및 전후 비교로 확인한다.

재질 교체나 자동 패킹 없이 기존 텍스처를 유지한다. UV 좌표 변화에 따른 텍스처 결과 변화는 편집의 의도된 효과지만, 지오메트리·재질 연결·다른 UV 채널 변화는 결함이다.

## 지원 범위 초안

| 항목 | V1 제안 | 확장 방향 |
|---|---|---|
| 호스트 | 사용자 실제 Max 버전 1개와 정확한 업데이트 빌드를 먼저 확정 | 검증한 버전만 지원 목록에 추가 |
| 언어 | Python/pymxs + 필요한 소규모 MAXScript 어댑터 | 병목 확인 시 C++ SDK |
| UI | 호스트에 동봉된 PySide 사용 | PySide2/6 호환 계층 |
| 오브젝트 | 단일 Editable Poly 기반, 안정된 최적화 결과 | 다중 오브젝트, 검증된 인스턴스 정책 |
| modifier | 최적화 이후 새 Unwrap 또는 명시적으로 선택한 유효 Unwrap | 중간 스택 편집은 대응 검증 후 |
| 재질 | Multi/Sub-Object → Standard/Physical → Bitmap | 렌더러별 어댑터, 복합·절차형 맵 |
| UV | 채널 명시, 음수·0–1 밖 좌표 보존 | 다중 UDIM 이미지 및 타일별 해상도 |
| 제외 | Patch, 애니메이션 UV, 편집 중 토폴로지 변경, 자동 Collapse | 필요성·API 검증 후 재평가 |

위 범위는 구현 편의를 위한 숨은 생략이 아니다. 미지원 대상은 감지하여 쓰기를 중단하고 이유를 표시한다. UDIM 좌표를 보존하는 것과 UDIM 이미지 전체를 자동 탐색·표시하는 것은 별개의 기능이다.

## 성공 기준

- 선택이 바뀌어도 실제 조작 가능한 기즈모가 유지된다. 화살표만 표시되는 모형은 실패다.
- 점의 선택·비선택·Hover가 텍스처 위에서 구분된다.
- Material ID 1/2/3 및 비연속 ID가 올바른 이미지를 선택한다.
- 좌표 편집 후 지오메트리·UV 연결·재질 연결·다른 채널은 불변이다.
- 드래그 한 번이 Undo 한 번이며, 취소·예외·Redo 후에도 일관성을 유지한다.
- 테스트 결과와 성능 수치를 실제 Max에서 기록하기 전까지 '동작 검증 완료'라고 표시하지 않는다.

## 문서 안내

| 문서 | 내용 |
|---|---|
| [FEATURE_SPEC.md](FEATURE_SPEC.md) | F01–F06, 추가 기능, 동작 정책·수식 |
| [TECHNICAL_FEASIBILITY.md](TECHNICAL_FEASIBILITY.md) | 공식 API 근거, 제품 비교, 한계·PoC |
| [ARCHITECTURE.md](ARCHITECTURE.md) | A/B/C 비교, 데이터·트랜잭션·성능 설계 |
| [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) | V0 기술 검증, V1–V4, 개발량·게이트 |
| [TEST_PLAN.md](TEST_PLAN.md) | Test A–F, 무결성·성능·실패 복구 |
| [TOKEN_BUDGET.md](TOKEN_BUDGET.md) | 모델 추천, 항목별 최소/기준/최대 예산 |

## 개발 착수 시 확정할 정보

정확한 Max 버전/빌드, Python/Qt 버전, 렌더러와 실제 재질 클래스, 대표 에셋의 UV 점·면 수, 텍스처 형식/해상도/UDIM 여부, 씬 시스템 단위, 인스턴스 사용 여부, 기즈모 문제 재현 순서가 필요하다. 계획 수립은 이 정보 없이 완료할 수 있지만 해당 환경에서의 제품 동작 보증은 할 수 없다.
