# 회사 Max 2023 이어하기

이 패키지는 LSY UV Repair **V0 검증 도구**다. 완성된 UV 복구 제품이나 설치 프로그램이 아니다. [실행 가이드](README.md)와 [Max 2024.2.7 테스트 기록](results/2026-10-13-teapot-max2024.md)을 함께 읽는다.

## GitHub에 접속할 수 있을 때

승인된 회사 환경에서 `https://github.com/Rimson01/uv`의 `main`을 내려받아 `v0/LSY_UV_V0.ms`를 실행한다. 회사 PC에서 GitHub 접속이 차단되어 있다면 아래 오프라인 방법을 사용한다.

## GitHub에 접속할 수 없을 때

집에서 만든 `LSY_UV_V0_offline_2026-10-13.zip`을 **회사에서 허용한 파일 반입 경로**로 전달한다. 회사 정책상 외부 스크립트 반입이나 실행이 허용되지 않으면 IT/보안 담당자의 승인된 절차를 따른다. 차단을 우회하기 위해 개인 메일·USB·클라우드 등을 사용하지 않는다.

ZIP을 허용된 폴더에 풀고, Max 2023에서 새 Teapot 같은 간단한 테스트 씬을 만든다. 회사 자산을 바로 열지 말고 Editable Poly와 Unwrap UVW 하나를 추가한 테스트 씬을 다른 이름으로 저장한다. Max 메뉴 **Scripting → Run Script**에서 `v0/LSY_UV_V0.ms`를 선택한다. UV Editor는 Modify 패널에서 직접 연다.

1. `P0 Diagnose selected object`를 누르고 실제 Max build와 Unwrap/UV 정보를 확인한다.
2. UV 점 8개를 선택한다. **Move 모드를 먼저 선택**하고 `Capture selected UVs` → 마우스로 한 번 드래그 → `Compare after drag`를 누른다.
3. UV Editor를 다시 활성화하여 Ctrl+Z를 **한 번** 누르고 `Compare after Undo`를 누른다. 다시 UV Editor를 활성화하여 Ctrl+Y를 **한 번** 누르고 `Compare after Redo`를 누른다.
4. Rotate와 Scale은 **모드 선택 후 새로 Capture**하여 같은 순서를 각각 한 번씩 반복한다. 모드를 바꾸거나 Redo 비교를 마치면 이전 캡처는 폐기된다.
5. `Save report`로 `v0_work_2023.txt`를 회사의 승인된 저장 위치에 저장한다. 필요한 경우 Listener의 오류 메시지와 Max build도 함께 기록한다.

Max 2024.2.7에서는 8점 Move와 Scale의 단일 drag/Undo/Redo가 통과했다. 마지막 첫 번째 통과 사이클은 Rotate 테스트 요청 직후였지만, 발췌 로그에 모드명이 없어 Rotate라고 확정하지 않는다. Max 2023/2025 호환성, 장시간 반복 안정성, Multi/Sub Bitmap 조회는 아직 검증하지 않았다.

회사 씬·재질 경로·보고서를 공개 GitHub나 개인 채팅에 올리지 않는다. 결과 공유가 허용되면 회사 자산명과 경로를 제거한 재현 단계, Max build, PASS/FAIL 수치만 전달한다. 외부 반입·반출이 허용되지 않으면 회사 내부에서만 기록하고, 다음 작업 때 이 문서의 상태를 기준으로 이어간다.
