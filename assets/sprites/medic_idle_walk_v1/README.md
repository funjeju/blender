# 의료진 idle / walk — 오른쪽 옆모습

- idle: 4프레임, 4fps, 루프 1초.
- walk: 4프레임, 8fps, 루프 0.5초.
- 프레임 256×256 RGBA. 아틀라스 1024×512, 위 idle / 아래 walk.
- `sprites.tres`를 AnimatedSprite2D의 SpriteFrames에 지정한다.
- 원화 생성: OpenAI 내장 image_gen, 최초 1회와 걷기 교정 1회를 각각 사용자 승인 후 실행.
- 프롬프트: sprite-workspace/specs/medic_idle_walk_v1.json, medic_walk_correction_v1.json.
- 원본: sprite-workspace/runs/medic_idle_walk_v1/raw/. 원본 보존, sprite-gen으로 투명 배경 정리·분리·정렬·조합.
- source run의 curation.json에 정렬 오프셋이 기록되어 있다. 새 원화를 자동 생성하지 않는다.
- 단일 옆모습 팩이다. 좌향은 수평 반전, 상하 이동에는 별도 앞·뒷모습 프레임이 필요하며 몸 전체를 회전하면 안 된다.

검증: 실제 Godot에서 8개 고유 프레임·투명도·4/8fps·루프·상태 변경·정지/재개 확인. 자동 idle 저동작 경고 0.0082 < 0.01은 미세한 호흡으로 검토 후 수용했다. APNG 미리보기는 각 프레임 250/125ms, GIF는 포맷 시간 단위에 맞춰 walk 120/130/120/130ms(전체 500ms)다.
