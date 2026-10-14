# LSY UV Workbench 0.12

단독 MAXScript 파일 하나로 실행하는 native UV 작업 패널이다. 이번 버전은
재질 배경과 native ID 표시 연결을 정리하고 유사 섬 Exact 검색을 제공한다.

## 시작

1. 씬을 별도 저장하고 V0 검증 패널을 닫는다.
2. `LSY_UV_Workbench_v012.ms`를 Scripting → Run Script로 실행한다.
3. 오브젝트와 활성 Unwrap을 선택하고 **대상 연결**을 누른다.
4. 왼쪽에서 면 자동 배경을 켜고 필요한 도구의 접이식 섹션을 펼친다.
   창 크기를 드래그하여 조절할 수 있다.

## 0.12: 배경/ID 표시 순서 정리 — host 검증 대기

자동 연동에서 숫자 index만 쓰던 경로와 기본 배경 영역의 수동 index 선택을 제거했다.
Qt QComboBox뿐 아니라 실제 QMenu/QAction 항목도 검색한다. ID 뒤 재질 이름에 숫자/점이
포함된 라벨을 지원하고, same-ID 내용을 가진 메뉴가 여럿이면 적용하지 않는다.
메뉴 변경은 실제 action.trigger + checked 확인, combo 변경은 실제 currentIndex 확인으로 수행한다.
뷰포트 face/vertex 선택 명령은 이 표시 경로에 없다.

단일 면 ID 변경의 순서:

1. 순정 자동 배경을 끄고 실제 UI에서 All IDs 항목 선택.
2. 기존 material→원본 Bitmap 경로로 이미지 적용.
3. 실제 UI에서 선택 면의 Material ID 항목 선택.
4. 선택된 배경 map이 필터 적용 후에도 같은지 확인.

확인 실패 시 ID 표시 연결을 끄고 All IDs/배경만 복구한다. 숫자 getMatID readback만으로
실제 표시 성공을 주장하지 않는다. 동일 ID/시간/채널/재질/파일/필터/배경이면 반복 전환하지 않는다.
UV Edit mode에서는 배경/ID를 고정하고 Face 자동 복귀 시 다시 갱신한다.
원래 값은 소유 변경으로 보관하며 복원 불가 항목은 기록한다.

64개 CPU/reference/소스 계약/빌드 검사가 통과했다. Python helper는 단독 .ms에 포함되어
별도 설치가 필요 없다. **이 환경에는 3ds Max가 없어 실제 메뉴 노출·화면 격리·배경 동시
변경은 검증할 수 없다. 이 릴리스는 구현 후보이며 해당 문제의 해결 완료 판정이 아니다.**
유효한 native 메뉴/checked 항목을 호스트가 노출하지 않으면 원인과 UI 종류/항목 수를 표시하고
적용하지 않는다. 실제 host 검사 없이 새 UI backend가 동작한다고 가정하지 않는다.

## 0.11.7: 배경 전환 우선 복구

사용자가 ID 숫자만 바뀌고 실제 표시가 바뀌지 않으며 자동 배경도 악화됐다고 보고했다.
Native ID/auto background 연동은 성공 기능으로 집계하지 않는다.
자동 격리는 비활성 보류하고 기존 material→Bitmap 배경 경로로 돌아간다.
배경 작업 전에 native auto background를 끄고 Material ID 필터를 0(All IDs)로 돌려
필터가 texture dropdown을 줄이거나 캐시된 배경을 덮어쓰는 충돌 경로를 제거한다.
원래 필터/auto 상태는 소유 변경 복원 기록에 보관하며 뷰포트 선택은 쓰지 않는다.
면 ID별 자동 배경과 ID 격리 동시 동작은 여전히 미해결이다.
클라우드 검사 56개 통과. 이 배경 복구 경로 자체도 아직 host 미검증이다.

## 0.11.6: 선택 면 ID와 순정 자동 배경 연동

대상 연결 → UV Editor 열기 → **면 자동 배경** 켜기.
기본 체크된 **면 ID 필터 + 자동 배경**은 선택 면의 실제 ID를 사용해 native `setMatID`와
`SetAutoBackGround true`를 함께 적용한다. Native 자동 배경은 Material ID 필터에 묶이는
문서화된 경로이며, 이 경로에서는 texture dropdown 탐색/등록 API를 호출하지 않는다.
뷰포트 선택/geometry는 변경하지 않는다. 다른 ID 면을 선택하면 필터/배경이 함께 변경된다.
혼합 선택은 원래 필터로 복원하고 빈 선택은 이전 표시를 유지한다.
고정 · 점 편집은 현재 이미지/ID를 유지하고 native 자동 배경을 잠시 끈다.

Native ID index는 All IDs=0, 이후 used face ID 오름차순 항목으로 대응한다.
ID 개수가 native 목록과 맞는지 확인하고 불일치하면 중지한다. 이 순서 대응은
실제 sparse-ID 모델의 항목 의미까지 호스트에서 검증된 것은 아니다.
55개 자동 검사 통과. 새 native 자동 연동은 실제 Max에서 아직 미검증이다.

근거: Max 2023 Unwrap Main Toolbar `SetAutoBackGround`: 현재 Mat. Filter ID를 변경하면
해당 ID를 사용하는 맵으로 배경이 자동 전환됨.

## 0.11.5: 순정 표시 항목 직접 변경

자동 ID 연결은 기본으로 끈다. 대상 연결 후 배경 섹션의 **순정 UV Editor ID 표시 항목**을
선택하면 `setMatID`로 순정 필터 index를 직접 바꾸고 readback을 확인한다.
별도 항목 **현재 목록 읽기**로 순정 현재 index/count를 다시 읽는다.
이 항목 번호는 실제 Material ID 숫자와 다를 수 있다. ID/재질 이름은 순정 드롭다운에서 확인한다.
마지막 항목이 native API에서 거부되면 원래 필터로 복원한다. 뷰포트 선택은 쓰지 않는다.
자동 컨트롤 탐색과 관계없이 직접 변경하며 실제 Max의 새 직접 선택 경로는 미검증이다.

## 0.11.4: ID 항목 구조 차이와 자동 진단

Qt ID matcher가 used-ID 개수와 드롭다운 개수를 같다고 요구하던 조건을 제거했다.
미사용 ID가 포함된 실제 항목 목록, ID/재질 이름 suffix, generic QWidget로 노출된
QComboBox를 처리한다. texture filename의 숫자는 ID로 취급하지 않는다.
실패 시 expected ID, visible combo 개수/항목 수, native ID count/current index를
같은 오류 로그에 자동 표시한다. 아직 host 미검증이며 필터 해결 완료가 아니다.
기존 확인된 Exact 검색/선택은 유지한다. 자동 검사 54개 통과.

## 0.11.3: Qt Material ID 필터 탐색

사용자 Max에서 Exact 검색과 결과 면 선택 성공 확인. Win32 ID 필터 탐색은 실패했다.
Win32 탐색 실패 시 Max 내장 Python/PySide2(또는 PySide6)의 실제 QComboBox 항목을
읽는 fallback 추가. Sparse ID의 실제 항목 순서를 사용하고 중복/모호한 컨트롤은 거절한다.
적용은 `setMatID`만 사용하며 native index와 Qt 선택 항목을 함께 확인한다.
외부 Python 설치/동반 파일은 필요 없다. Qt 경로 자체는 아직 host 미검증이다.
클라우드 검사 52개 통과. 정상 Exact 검색/선택 경로는 유지한다.

## 0.11.2: 검색 배열과 native 목록 변화 대응

검색의 face-key 배열 복사는 `copy` 대신 명시적 collect로 만든다.
후보 없음은 일반 상태 메시지로 처리하고 불일치/ID 제외 수도 표시한다.
ID dropdown 탐색은 DPI/창 재배치에 취약한 window rectangle 일치 조건을 제거하고
같은 Max 프로세스의 실제 combo 항목 전체를 대조해 유일한 후보만 사용한다.
배경 목록의 개수 관계가 기존 실측과 달라지면 map 이름과 실제 dropdown 항목으로
대응을 찾는 fallback을 사용한다. 중복/불명확 이름이나 숨겨진 맵은 적용하지 않는다.
자동 전환은 ID 표시 필터를 먼저 적용한 뒤 해당 배경을 찾는다.
복원 불가 상태는 기록하고 현재 배경을 유지해 재연결을 차단하지 않는다.
49개 클라우드 검사 통과. 새 native dropdown 경로/Max 검색 동작은 아직 host 미검증이다.

## 0.11.1: 예약어 변수명 수정

MAXScript 예약어 `mapped`를 지역 변수로 선언한 구문 오류를 수정했다.
canonical helper와 단독 파일에 `mappedCorners`를 사용한다. 자동 검사 47개 통과.
실제 Max 컴파일은 아직 미검증이다.

## 0.11: UV Editor ID 필터와 Exact 유사 섬 검색

**ID 필터**는 뷰포트의 면/점 선택이나 geometry 숨김을 바꾸지 않는다.
현재 오브젝트의 실제 ID 목록과 기존 Editor 드롭다운의 항목을 Win32 read-only 메시지로
대조하고, 공개 `setMatID` API로 표시 필터만 바꾼다. C# helper는 단독 .ms에 포함되어
Max의 .NET에서 메모리 컴파일된다. 외부 설치 파일은 없다.
UI 드롭다운이 확인되지 않거나 index 대응이 불명확하면 필터를 유지하고 원인을 표시한다.
숫자 ID를 filter index로 그대로 넘기거나 sorted 순서를 추측하지 않는다.
이전 버전의 선택 면 필터는 해제 대상으로만 다루며 새 선택 확장 격리는 제거했다.
이 bridge의 실제 Max 2023/.NET 컴파일과 UI 읽기는 아직 미검증이다.

**정확한 섬 기반**: 같은 geometry edge와 양 끝 UV 인덱스를 공유하는 면으로 연결한다.
점 하나만 접한 면, 겹친 독립 UV, seam 복제는 분리한다. 비정상 UV/geometry 공유,
퇴화 edge, nonmanifold edge는 분석을 막는다. 읽기 범위: 20,000면/100,000 UV점 이하.
기존 UV 섬 선택도 이 기반을 사용하며 Face 모드를 지원한다. Vertex 모드에서
여러 섬이 공유한 UV 점을 seed로 삼으면 양쪽이 incident할 수 있으므로 면 seed를 권장한다.
선택 검증은 trailing false BitArray 길이 대신 실제 집합을 비교하고 mismatch 시
requested/actual/missing/extra를 표시한다. 이 수정이 native 선택 문제를 해결했다는 호스트 증거는 없다.

**유사 UV 섬 — Exact 사용법**:

1. 한 섬의 면/점을 선택하고 **기준 섬 지정**을 누른다.
2. **유사 섬 검색**: 같은 node/channel/Material ID 안에서 전체 점/면 연결을 검사한다.
3. 목록에서 Exact/대칭/미판정 결과를 확인한다.
4. **Exact 결과 선택**: 대응이 하나인 Exact 후보의 면만 선택한다. 기준 섬은 제외한다.

연속 회전+translation 허용, scale/mirror 제외. 최대 128 UV점/섬,
anchor 시도 최대 512, 전체 검색 약 5초 제한. 한계 초과와 coincident 독립 점은 미판정이다.
전체 좌표 최대 잔차와 면-corner cyclic incidence까지 확인한다. bbox/점 개수만으로 선택하지 않는다.
대칭으로 여러 대응이면 별도 표시하고 자동 선택에서 제외한다. 기준 지정 후
UV/time/channel/topology/Material ID가 변하면 재지정하도록 막는다.
검색은 읽기 전용이며 결과 선택은 명시 버튼+Undo로 수행한다. 좌표는 바꾸지 않는다.

Python reference fixture/공식 member 계약/빌드 검사 46개 통과.
이 검사는 MAXScript/Win32 UI를 실행하지 않는다. 새 분석·native 필터·결과 선택은 host 미검증.
F03 초기 Exact 구현이며 Approximate, mirror/scale 옵션, anchor 기반 대칭 해소,
별도 검색 취소 버튼, Stack/ghost preview/Density는 아직 없다.

## 0.10: 세로 패널과 균등 간격 도구

가로 3열/flow 배치를 폐기했다. 기본 330×760, 최소 330×420의 세로 스크롤 패널이다.
배경 → 빠른 변환 → 정렬·좌표 → 타일·픽셀 → 색상·표시 → 재질 상세 순서로 놓는다.
정렬 이하 섹션은 기본으로 접으며 필요한 섹션의 제목을 눌러 펼친다.
기본 UV Editor의 기능별 세로 섹션 구성을 참고했다. 자체 기호 아이콘은 사용하지 않는다.
창 크기에 따라 폭/스크롤 높이는 조절되지만 옆 열로 이동하지 않는다.

**자동 추적 오류 처리**: ID 격리와 배경 조회를 독립 처리한다. 격리가 실패하면 격리만
끄고 배경 추적은 유지한다. 실제 오류 이유를 패널/Listener에 표시한다.
선택 readback은 BitArray 길이가 아니라 실제 켜진 인덱스로 비교한다.
사용자가 보고한 일반 오류 문구만으로 최초 예외 원인을 확정할 수 없으므로
이 변경은 오류 경로 수정이며 실제 asset의 자동 배경 문제가 완전히 해결됐다는 증거는 아니다.

**U/V 균등 간격**: Vertex 모드의 선택 점만 수정한다. 해당 축의 서로 다른 좌표를
정렬하고 최소/최대 사이를 같은 간격으로 배치한다. 같은 축 좌표의 점들은 함께 유지한다.
다른 축/W는 유지하고, 타일 밖 값을 wrap하지 않는다. 하나/두 좌표 수준은 변경하지 않는다.
UV 연결 순서로 체인을 펴는 Straighten 또는 섬 패킹 기능은 아니다. 기존 좌표 쓰기/Undo 경로 사용.

클라우드 자동 검사 38개 통과. 실제 Max의 최신 UI·배경/격리·좌표 쓰기·Undo는 미검증이다.

## 0.9.5: 초기 패널 겹침 수정

Max에서 정의되지 않은 `setRolloutState` 호출 때문에 open handler가 배치 전에 중단됐다.
해당 호출을 전부 제거하고 기본 펼침 상태의 독립 패널을 배치한다.
초기화 경로에 이 호출이 남지 않는 회귀 검사 추가. 자동 검사 34개 통과.
실제 Max 실행은 아직 미검증이다.

## 0.9.4: 너비에 따라 옆으로 펼쳐지는 패널

6개 섹션을 독립 패널로 분리했다. 배경 → 좌표 → 타일 → 기존 Max → 표시 → 재질 상세
순서로 배치한다. 창을 넓히면 열 수가 2~6개로 늘어나 아래 패널이 오른쪽으로 올라온다.
좁히면 다음 줄로 내려간다. 약 1624px 이상이면 6개가 한 줄에 놓인다.
패널 내부 내용이 높이를 넘으면 해당 패널만 스크롤한다.
최소 크기는 760×380이며 실제 `getDialogSize`를 읽어 resize 이벤트 누락도 보완한다.
기존 3열 고정 배치는 제거했다. Max에서 실제 새 배치는 아직 미검증이다.

## 0.9.3: 섹션 내부 도구가 잘리는 초기 배치 수정

0.9.2는 모든 컨트롤을 초기 `pos:[8,8]`로 만든 뒤 resize에서 옮겼다.
이 초기 겹침으로 SubRollout이 콘텐츠 높이를 지나치게 작게 잡을 수 있었다.
컨트롤 생성 시 실제 행/열 위치와 폭을 지정해 아래쪽 도구까지 콘텐츠 범위에 포함한다.
초기 배치와 resize 수식의 일치를 회귀 검사한다. 선택 사항 섹션은 명시적으로 접는다.
이전 배경 복원/체크박스 폭 수정 포함. 클라우드 검사 33개 통과.
새 SubRollout 표시 결과는 실제 Max에서 아직 실행 검증하지 못했다.

## 0.9.2: 드래그 크기 조절 오류 수정

사용자 Max 2023에서 `CheckBoxControl.width` 실행 중 변경이 지원되지 않는 오류를 확인했다.
체크박스 폭은 생성 시 지정하고 resize에서는 위치만 변경한다. 다른 자식 컨트롤은
`isProperty ... #width`로 확인한 뒤 폭을 변경한다. 최소 크기 보정의 재진입도 막는다.
0.9.1 배경 복원 수정 포함. 클라우드 자동 검사 32개 통과.
새 resize 경로는 실제 Max에서 아직 실행 검증하지 못했다.

## 0.9.1: 배경 복원으로 인한 재실행 차단 수정

새 복원 helper를 이전 버전 종료보다 먼저 정의한다. 원래 맵과 적용 맵이 같으면
인덱스 조회 없이 그대로 유지한다. 배경 표시/자동 배경은 각각 독립 복원한다.
맵 목록 변경 또는 원래 맵 삭제는 인덱스를 추측하지 않는다. 재실행 시 현재 배경을
유지하고 미복원 상태를 `lsyUVPendingBackgroundRestores`에 보관해 시작을 계속한다.
그 밖의 오류 메시지는 Listener에 출력한다. 기존 표시 복원/격리 복원 실패는 여전히 중지한다.
개발자 host runner에 stale 목록 + 같은 맵/다른 맵 복원 사례를 추가했다.
클라우드의 31개 자동 검사는 통과했으나 Max에서 새 복원 경로는 아직 미검증이다.

## 0.9: 가로형 UI와 재질 ID 격리

별도 점 보기 창 없이 기존 UV Editor를 사용한다. 창의 모서리를 드래그하면
3열 배치의 폭과 스크롤 영역 높이가 함께 변한다. 기본 1040×560, 최소 1000×380.
버튼은 26px 높이와 최대 100px 폭의 짧은 텍스트를 사용하고 툴팁을 유지한다.
창 확대 시 입력 필드/정보 영역은 늘어나며 버튼은 지나치게 커지지 않는다.

- 왼쪽 **배경**: 면 자동 배경, 고정, 점 편집, 면 자동 복귀, 이미지 선택,
  배경 복원, 같은 ID만 보기, 전체 UV 보기.
- 가운데 **좌표·선택**: 정렬, 회전, 크기, 반전, 미세 이동, UV 섬 선택.
  타일·픽셀 도구는 접어서 제공한다.
- 오른쪽 **기존 Max 도구**: 이동/회전/스케일과 화면 탐색.
  표시 설정과 재질 상세(ID 직접 입력/슬롯 조회/엣지 편집/진단)는 접어서 제공한다.

**면 자동 배경**을 켜면 기본 체크된 **같은 ID만 보기**가 작동한다.
선택 면의 ID가 하나이면 같은 ID의 모든 면으로 선택을 확장하고
native `setFilterSelected true`로 선택 면만 표시한다. 재질 ID/UV 좌표/숨김 상태는 쓰지 않는다.
Sparse ID 2/7/42도 실제 face ID 비교로 처리하며 dropdown index를 추측하지 않는다.
배경 고정 후 점/엣지 모드에서는 이전 격리를 유지한다.
여러 ID 선택은 격리를 해제하고 배경은 유지한다. 빈 선택은 이전 배경/격리를 유지한다.
전체 UV 보기, 자동 끄기, 배경 복원, 대상 재연결, 창 닫기에서 필터를 복원한다.
면 선택은 마지막 자동 선택과 같을 때만 원래 선택으로 돌려 외부 편집을 보존한다.
**격리는 같은 ID 전체 면 선택으로 기존 선택을 변경한다.**
외부에서 같은 필터값을 재설정한 경우는 패널 변경과 구분할 수 없다.

기존 Editor의 미선택 점 표시 문제는 해결 방법을 찾지 못해 보류했다.
0.8.1의 `catch` 재던지기 수정도 포함했다. 클라우드 검사 31개 통과.
실제 Max의 새 UI resize/배치, 격리 표시와 기존 선택 복원은 아직 실행 미검증이다.

## 편집 도구

- UV 섬 선택: 선택 점에서 연결된 UV 섬으로 확장하며 분리된 Seam 인덱스는 건너지 않는다.
- 선택 반전/해제: 실제 사용하는 UV 점 기준. Vertex 모드, Undo 지원.
- U/V 픽셀 스냅: 직접 입력한 이미지 폭/높이의 픽셀 경계로 반올림.
  각각 실행하며 W와 다른 축은 유지한다. 픽셀 중심이나 맵 tiling/offset 보정은 하지 않는다.
- U/V 크기 적용: 좌표 섹션의 크기 %를 해당 축에만 적용한다.
- 타일 이동: 지정한 정수 타일 수만큼 선택 점을 이동한다.
  음수/1 이상 좌표를 유지하며 wrap/clamp/pack하지 않는다.

## 색상 수정

기존 코드는 Color picker의 0~255 RGB를 float Point3에 그대로 전달했다.
0.5는 각 채널을 255로 나누어 Max Color의 0~1 범위로 보낸다.
적용 후 실제 getter 값을 재조회하여 요청 색상과 맞는지 확인한다.
선택 점 크기/색상은 **Vertex 모드의 선택한 UV 점**에 적용된다.
비선택 점 크기/색상과 Hover는 이 native API로 따로 제어하지 않는다.

- **색상/크기 변경 즉시 적용**: 켜져 있으면 바꾸는 즉시 적용한다.
- 선택 점, 일반 UV 선, 경계/Seam, 기즈모, 공유 UV 색을 분리했다.
- 경계선 표시 / 공유 UV 강조를 독립적으로 켜거나 끌 수 있다.
- **고대비 프리셋**은 선택 점 8, hit 8, 노랑 점/청색 선/녹색 경계/흰색 기즈모로 적용한다.
  공유 UV 강조는 꺼서 선택 점 색을 확인하기 쉽게 한다.
- **Vertex 모드로 색상 확인**은 Editor를 열고 점 선택 모드로 바꾼다. 점을 자동 선택하지 않는다.
- 대상 연결 시 현재 표시값을 읽는다. 원래 값은 최초 적용 직전에 보관한다.
- 표시 복원/닫기에서 패널이 적용한 값과 일치하는 항목만 원래 값으로 돌린다.
  외부에서 바뀐 다른 값은 보존한다. 동일 값을 외부에서 재설정한 경우는 구분할 수 없다.

범위 근거: [Max SDK Color](https://help.autodesk.com/cloudhelp/2023/ENU/Max-Developer-Help/cpp_ref/class_color.html),
[Unwrap Preferences](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-99222CE9-9679-4879-BCB9-C1338AEE9A75.html).
V0 표시 적용에도 같은 RGB 변환 오류를 수정했다.

## PBR / 재질 배경

기본 흐름은 **Face 자동 → 면 선택 → 고정 + 점 편집**이다.
Vertex/Edge 편집에서는 자동으로 배경을 바꾸지 않는다. 혼합 ID/선택 없음은 마지막 배경 유지다.

Standard/Physical 속성 외에 scripted **PBR Material (Metal/Rough)**의 맵 슬롯도 조회한다.
공개 API의 비지역화 슬롯 이름과 명시적인 Base/Albedo 맵 파라미터를 검사한다.
Base/Albedo/Base Color/Diffuse만 자동 후보로 인정하며 Normal/Roughness/Metalness/ORM은 제외한다.
후보가 모호하면 임의 첫 맵을 선택하지 않는다. 실제 사용자 PBR 재질에서의 결과는 아직 미검증이다.

- **재질 ID → 이 ID의 배경 사용**: 면의 ID를 변경하지 않고 해당 이미지만 사용한다.
- **ID 맵 슬롯 목록**: 입력 ID의 할당된 맵 슬롯을 읽는다. 목록에서 직접 선택하면 그 슬롯을 배경으로 사용한다.
  이 경로는 사용자 명시 선택이므로 Normal 등 다른 Bitmap도 참조 배경으로 사용할 수 있다.
- 슬롯 목록은 대상/재질/ID 변경을 감지하고 오래된 항목을 적용하지 않는다.
- 상대 경로는 현재 Max의 texture search path를 읽어 찾으며 material.filename 자체는 변경하지 않는다.
- OSL/절차형/중첩 texmap는 원본 Bitmap으로 임의 해석하지 않는다. 이미지 파일 선택을 사용한다.
- Multi/Sub의 비연속 ID를 실제 슬롯으로 해석하고, 비활성/누락/중복 ID와 순환/과도한 중첩을 처리한다.
- 이미지는 원본 참조다. tiling/offset/rotation/crop/OCIO나 최종 renderer appearance의 복제는 보장하지 않는다.

슬롯 API 근거: [Material Common Methods](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Material-MAXWrapper/GUID-23A6A316-7C51-430C-8A44-9236C837DB10.html).
`localizedName:false`는 Max 2022 이상에서 지원한다.

## 실제 UV 좌표 도구

**고정 + 점 편집** 후 UV 점을 선택한다. 각 명령은 선택한 점의 현재 좌표에서 계산한다.

| 도구 | 동작 |
|---|---|
| U/V 최소·중앙·최대 정렬 | 선택 범위의 해당 축 값으로 점들을 정렬. 다른 축/W 유지 |
| ±각도 회전 | 선택 bbox 중심을 기준으로 입력 각도 회전 |
| 크기 % | 같은 중심에서 U/V를 같은 비율로 확대·축소. 음수 대신 명시적 반전 사용 |
| U/V 반전 | 해당 축을 선택 중심 기준으로 반전 |
| 중심을 0.5로 | 전체 선택을 평행 이동하여 중심을 (0.5, 0.5)로 배치. 패킹/클램프가 아님 |
| U/V 미세 이동 | 입력한 UV 값만큼 이동. 픽셀/cm 단위가 아님 |

빈 선택은 전체 선택으로 해석하지 않는다. W값과 UV 연결/geometry/material은 쓰지 않는다.
좌표를 바꾸지 않는 명령은 Undo를 만들지 않는다. 실제 좌표 쓰기는 하나의 named Undo 범위에서
node 명시형 setter와 hold=true/update=false로 수행하고 마지막에 view를 갱신한다.
읽기 재검증이 실패하면 캡처한 좌표를 복원하고 확인한다. 복원 확인에 실패한 대상은 추가 좌표 편집을 차단한다.
**실제 Max의 좌표 쓰기/단일 Undo 동작은 아직 미검증**이다. 기존 V0 native drag 통과와 별개다.

지원: Editable Poly + Unwrap 하나, Vertex 모드, 단일 노드가 사용하는 modifier, UV 채널.
공유/instanced modifier는 지원하지 않는다. 유한값 및 절댓값 1e12 미만 좌표만 처리한다.
선택 집합 전체의 bbox 중심을 쓰므로 여러 island를 고르면 공통 중심으로 변환한다.
이것은 island별 solver/stack/weld 또는 native soft-selection drag가 아니다.

좌표 API 근거: [Unwrap Topology Editing](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-E40598B1-859E-4E30-A2DB-93E6F80A2226.html).

## 데이터 수명과 검증

Editor map 목록에는 등록된 맵이 남을 수 있다. 실제 texMapList identity/유일 경로를 검색하며
addMap의 개수 증가를 가정하지 않는다. 관찰된 Max 2023은 dropdown index = texture-list index + 1이며
읽기/복원에도 역변환을 적용한다. 다른 목록 크기 관계는 추정하지 않고 중지한다.
닫을 때 timer와 live UI 적용을 중지하고 패널 소유 표시/배경 설정을 복원한다.
좌표 편집 결과는 닫아도 유지되며 Ctrl+Z로 되돌린다. native 도구/선택 모드는 복원하지 않는다.
진단 파일에는 버전, 맵 목록/인덱스, 현재 색상 getter 값과 모드를 저장한다. 전체 asset 경로와 scene/object 이름은 제외한다.

클라우드 검사:

```sh
python3 -B -m unittest discover -s tests -v
```

색상 변환, PBR 슬롯 분류, 실제 출력 코드와 공유하는 좌표 수식, W 보존, 잘못된 입력,
공식 SDK member 계약, 단독 BOM export를 검사한다. native Max 컴파일/표시/Undo의 대체 검사는 아니다.
`tests/workbench_host_tests.ms`는 소스에서 helper를 읽는 개발자용 Max 회귀 파일이며 클라우드에서는 미실행이다.

```sh
python3 -B v1/build_release.py /workspace/exports/LSY_UV_Workbench_v012.ms
```

빌더는 테스트된 수식과 source의 generated block이 일치하는지 확인하고 UTF-8 BOM 파일을 생성한다.
기존 export는 덮어쓰지 않는다. 사용자는 이 .ms 파일 하나만 필요하며 Python 설치/동반 파일은 필요 없다.

사용자 Max 2023에서 기존 native M/R/S 좌표 복원, 단일 Bitmap/Multi-Sub 조회와 수정된 Face 자동 배경은 확인됐다.
사용자가 0.5 선택 점 색상 동작을 확인했다. PBR 실제 자동 인식, 최신 UI/슬롯 선택, native 좌표 쓰기·Undo는 호스트 미검증이다.

### 0.12.1 review patch

User evidence invalidated 0.12 native UI discovery in Max 2023. This patch preflights read-only UI access before changing display settings, stops after ID apply failure, invalidates stale background caches, and guards timer reentry. Missing UI still blocks linked display; automatic ID/background integration remains unresolved. No Max host validation was possible in this cloud environment.
