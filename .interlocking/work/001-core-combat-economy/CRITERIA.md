# Acceptance Criteria — 001-core-combat-economy

구현 후 공통 실행 명령은 `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-NNN`이다. 각 fixture의 입력 자세·블럭 ID·기대 소유자는 테스트 대상 경기 로직이 아닌 `tests/fixtures/`의 고정 데이터로 정의하고, 불일치 시 runner는 0이 아닌 종료 코드를 반환해야 한다. 현재 저장소에는 `godot4`, `tests/regression_runner.gd`와 `tests/fixtures/`가 모두 없어 아래 10개 기준은 작성 시점에 읽기와 실행만으로 판정할 수 없다. 따라서 각 Method는 구현이 제공해야 할 검증 진입점의 정확한 계약이며, 해당 경로와 명령이 실제로 생기기 전에는 통과로 간주하지 않는다.

REQ-001
  Judged: 새 경기 직후 두 플레이어 각각에 서로 다른 ID의 요새 1개, 장전된 투석기 1대, 장전된 전차 1대, 예비 블럭 87개가 있고, fixture ID를 독립 집계하면 플레이어별 100개 및 전체 200개이다. 재초기화해도 배치와 수량이 같다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-001`

REQ-002
  Judged: 같은 fixture 형식으로 2명 및 3명 목록을 주입하고 순서를 바꿔도 식별자·예비·요새·병기·턴 행동이 ID 기준 해당 플레이어에게만 적용된다. 핵심 상태 모델은 장면 노드 타입/경로를 참조하지 않고, 플레이어별 별도 필드나 길이 2 쌍 배열 대신 동일 항목 타입의 목록을 쓴다. 동작만으로 구조적 부재를 증명할 수 없어 소스 검토가 필수다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-002`; 이어서 핵심 상태 모델 파일에서 단일 플레이어 항목 목록, Node 참조 및 P1/P2 전용 상태 부재를 검토한다(구현 전이라 파일:라인 지정 불가).

REQ-003
  Judged: 활성 플레이어의 장전된 미발사 병기에 독립 fixture의 마우스 press→drag→release를 한 번 주입하면 발사체가 정확히 1개 생기고 그 ID가 장전 블럭 ID와 같으며, 병기는 즉시 무장 해제·해당 턴 발사 완료가 된다. 비활성 플레이어 병기, 미장전 병기, 같은 턴 재발사에는 0개가 생긴다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-003`

REQ-004
  Judged: 발사체와 모든 판정 대상 구조 블럭의 속도를 독립 기록한 고정 물리 틱 fixture에서 발사 후 0.8초 전에는 해결되지 않는다. 0.8초 이후 모든 대상이 선형 속력 0.12 BL/s 이하 및 각속력 0.2 rad/s 이하를 연속 0.6초 유지한 다음 틱에만 정상 해결되며, 어느 대상이든 한 틱이라도 임계값을 초과하면 연속 시간이 0으로 재설정된다. 정확히 0.12 BL/s·0.2 rad/s는 안정, 각각 0.001 초과는 불안정이다. 계속 움직이는 fixture는 시뮬레이션 시간 8.000초에 타임아웃 오류와 재시도 수단을 노출하며 직전 스냅샷 대비 파괴·소유자·승자·블럭 ID가 변하지 않는다. 렌더 프레임률을 달리해도 같은 물리 틱에 같은 결과가 난다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-004`

REQ-005
  Judged: 서로 다른 기준 위치·회전을 가진 구조 블럭별 기준 자세를 안정 시점에 기록한 뒤, 짧은 변 0.2 BL인 독립 자세 fixture에서 각자의 기준 대비 이동 0.099 BL/회전 29.9도는 비붕괴, 이동 0.100 BL 또는 회전 30.0도는 붕괴이다. 다른 블럭의 기준 자세를 대신 적용하면 실패해야 한다. 구조 블럭 일부만 붕괴하면 완파가 아니고 전부 붕괴하면 완파이며, 장전 블럭 자세만 임계값을 넘어도 완파 여부는 변하지 않는다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-005`

REQ-006
  Judged: 정상 실패 fixture는 발사 블럭 1개만 방어자 예비로 옮긴다. 단일·다중 완파 fixture는 발사 블럭과 완파된 각 적 병기의 모든 구조·장전 블럭 ID를 정확히 한 번 공격자 예비로 옮기고, 미완파 병기 블럭은 옮기지 않는다. 같은 완파 신호를 두 번 전달해도 두 번째 전후 수량과 소유자가 같다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-006`

REQ-007
  Judged: 초기화, 발사 직후, 성공·실패·다중 완파, 중복 이벤트, 삭제 대기, 타임아웃 및 재시도의 각 전이 전후에 고유 ID를 독립 집계하면 예비+현장 구조+장전+발사체가 항상 정확히 200개이고 중복·누락·새 ID가 각각 0개이다. 관찰 가능한 결과 스냅샷에는 부분 적용 상태가 없다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-007`

REQ-008
  Judged: 순서를 A,B,C로 둔 3인 fixture는 1라운드 A에서 시작하고 허용된 종료마다 A→B→C로 정확히 한 턴씩 진행한다. A나 B 종료에는 라운드가 그대로이고 C 종료에만 1 증가해 다음 라운드 A가 되며, 여러 라운드 동안 누락·중복 턴이 0개이다. 한 해결에서 적 요새 구조 블럭 전부가 무너지는 fixture는 즉시 공격자를 유일한 승자로 하고 이후 입력이 결과를 바꾸지 않는다. 하나라도 남으면 승리하지 않고 해결 직전 물리 자세를 유지한다. 19라운드 및 20라운드 A/B 종료에는 최종 판정하지 않고, 20라운드 C 종료 즉시 21라운드를 만들지 않은 채 (a) 총 소유 101:99는 101 소유자 승리, (b) 총 소유 동률·요새 7:6은 7 소유자 승리, (c) 둘 다 동률은 무승부가 된다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-008`

REQ-009
  Judged: 해결 중과 타임아웃 오류 중 발사 및 턴 종료 입력을 반복하고 해결 콜백을 중복 전달해도 발사체 수, 활성 플레이어, 라운드, 병기의 무장 해제·해당 턴 발사 완료 상태, 모든 블럭 ID·소유권 및 결과 적용 횟수가 변하지 않는다. 8.000초 타임아웃 진입 때 발사체와 모든 판정 대상 구조 블럭의 자세·선형 속도·각속도를 독립 스냅샷으로 기록하고, 오류 상태에서 여러 물리 틱 뒤에도 각 값이 정확히 같다. 명시적 재시도 1회는 새 발사체나 블럭 이전 없이 같은 발사체 ID와 블럭 원장을 유지하고 저장된 자세·속도로 같은 발사를 재개하며, 해결 경과 시간과 연속 안정 시간만 각각 0으로 초기화한다. 재시도 후 안정 fixture에서는 정상 결과가 정확히 1회 적용되어 허용된 다음 상태로 가고, 계속 불안정한 fixture에서는 다시 8.000초 후 같은 보존 규칙의 오류로 돌아간다. 두 번째 재시도 후 안정되는 fixture도 전체 결과 적용 횟수가 정확히 1이다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-009`; fixture가 제공한 초기 ID·소유권·자세·속도 원장과 각 전이 스냅샷을 비교한다. 현재 저장소에는 `godot4`, runner와 fixture가 없어 실행으로 판정할 수 없다.

REQ-010
  Judged: Godot 4 headless 단일 실행이 고정 초기화, 성공·실패·동시 2개 이상 완파, 요새 승리, 20라운드 세 결과, 8.000초 타임아웃 보류와 모든 단계의 200블럭 보존을 각각 2회 통과하고 종료 코드 0을 반환한다. 플레이 화면은 현재 판정 상태와 독립 집계와 같은 전체 수량을 항상 보이고 타임아웃에는 오류와 재시도 수단을 보인다. 화면 주장은 실제 Godot 창에서 사람이 초기·해결·타임아웃을 조작 관찰해야 하며 headless로 대체할 수 없다.
  Method: `godot4 --headless --path . --script res://tests/regression_runner.gd -- --requirement REQ-010 --repeat 2`; 이어서 `godot4 --path .`로 위 세 화면의 상태명·총계·재시도 UI를 확인한다. 현재 환경에는 실행 파일이 없어 승인 전에 준비해야 한다.
