# 의료진 방향별 애니메이션

실제 앞모습(south), 뒷모습(north), 오른쪽 옆모습(east)을 각각 그렸다. 왼쪽은 east를 수평 반전한다. 전신 회전·세로 반전은 사용하지 않는다. 대각선은 가까운 4방향 중 하나로 표시하며, 8방향 고유 원화는 아니다.

- 각 방향: idle 4프레임 / 4fps / 1초 루프, walk 4프레임 / 8fps / 0.5초 루프.
- 24개 고유 프레임, 256×256 RGBA. 1024×1536 아틀라스와 sprites.tres.
- 원화: OpenAI 내장 image_gen. 옆모습 최초 1회·교정 1회, 앞·뒤 시트 추가 2회는 각각 명시적인 비용 불확실성 승인 후 실행. 남은 생성 승인 없음.
- 전체 프롬프트: sprite-workspace/specs/medic_idle_walk_v1.json, medic_walk_correction_v1.json, medic_south_animation_v1.json, medic_north_animation_v1.json.
- 원본은 sprite-workspace/references/generated 및 runs/medic_idle_walk_v1/raw에 보존했다.
- sprite-gen 2.45.3으로 로컬 분리·정렬·조합했다. idle의 저동작 경고는 미세한 호흡으로 검토했으며 보고서를 보존했다.

hospital.gd가 이 팩을 실제 사용한다. 이동하면 walk, 멈추거나 벽에 완전히 막히면 idle, 일시정지 중 프레임이 멈춘다. 사격 중에는 발사 방향의 그림을 선택하며 전신을 회전하지 않는다.

브라우저 작업본은 sprite-workspace/curation/medic_directional. 편집 내용은 게임 팩에 자동 덮어쓰기 하지 않는다. 새 버전으로 검수·게시 후 게임 참조를 바꾼다.
