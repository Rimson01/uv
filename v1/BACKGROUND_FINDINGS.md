# 자동 배경 회귀 원인과 0.14 변경

사용자 Max 2023 증거: `filter=0 auto=False maps=-6 texture-list=8 current-map=3`.

확인된 코드 결함:

1. ID 기능 추가 후 `setMatID 0`을 All IDs라고 가정했다. 공개 SDK 샘플의 `fnSetMatID`는 입력을 감소시키며, `fnGetMatID`는 내부 값+2를 반환한다. 샘플의 All IDs 내부 값은 -1, 공개 API index는 1이다. 0을 넣으면 내부 -2가 된다. 0.14는 All IDs를 1로 지정하고 UI에서 읽은 항목도 `slot+1`로 API에 넘긴 뒤 UI와 getter를 함께 확인한다.
2. `numberMaps`를 항상 정상 데이터 배열 개수로 취급했다. 공개 샘플은 UI combobox의 count에서 보조 항목 수를 뺀다. UI가 없거나 초기화되지 않으면 음수가 될 수 있다. 사용자 로그의 정확한 -6 내부 계산을 2010 소스로 설명할 수는 없지만, 음수는 정상 map count가 아니다. 0.14는 양수 control counts가 확인되기 전 UI 탐색/배경 쓰기를 하지 않고 대기한다. Face 자동의 edit 직후 모드 전환/배경 조회도 다음 timer tick으로 미룬다.
3. ID UI 발견 실패가 배경-only 처리도 중단했다. 0.14는 실험 ID 체크만 끄고 배경 처리를 계속한다. 뷰포트 선택/geometry hide는 사용하지 않는다.
4. catch 안에서 복원 함수를 호출한 뒤 `throw()`를 하면서 원래 예외를 다시 전달하려 했다. 0.14는 원래 내용을 먼저 보관하고 catch 밖에서 전달하며 처리 단계도 출력한다. 이것이 모든 `Unknown system exception`의 원인이었다는 의미는 아니다.

근거:
- [Autodesk 2023 Material ID API](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-A182EFF2-5FE1-4B2D-AC4E-DB3DB48136E9.html): getMatID/setMatID는 실제 Material ID가 아닌 dropdown index.
- [Autodesk 2023 map API](https://help.autodesk.com/cloudhelp/2023/ENU/MAXScript-Help/files/3ds-Max-Objects-and-Interfaces/Modifier-MAXWrapper-and/Modifier-and-SpacewarpModifier/Modifiers/UVW-Modifiers/Unwrap_UVW-Modifier/GUID-BE11A0A8-4280-46B4-ACAE-840CB96DB763.html): numberMaps는 dropdown count.
- [SDK 2010 publishedfunctions.cpp 공개 보관본](https://github.com/Jackster/AutoDeskSDKArchive/blob/master/3ds%20Max/2010/samples/modifiers/uvwunwrap/publishedfunctions.cpp): fnGet/SetMatID, fnNumberMaps. 2023 바이너리 구현을 대체하는 근거가 아니며 역사적 API 구현을 확인한 자료다.
- [SDK 2010 unwrap.cpp 공개 보관본](https://github.com/Jackster/AutoDeskSDKArchive/blob/master/3ds%20Max/2010/samples/modifiers/uvwunwrap/unwrap.cpp): All IDs entry와 internal matid=-1 초기화.

Max 2023에서 0.14를 실행하지 못했으므로 실제 자동 배경 복구/ID 표시 성공은 아직 미확인이다. UV Editor가 열려 있어도 map count가 계속 음수라면 해당 UI-backed API capability가 없는 상태로 남는다. 임의 map index로 강제 쓰기하거나 음수에 상수를 더해 정상 count를 만들지 않는다. 원래 map/ID 복원 전체 lifecycle도 host 검증이 필요하다.
