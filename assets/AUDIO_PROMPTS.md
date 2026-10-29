# 끝없는 병원 — 배경음·효과음 제작 프롬프트

병원 생존 게임용 후속 제작안. **이 프롬프트로 유료 오디오 생성은 실행하지 않았다.** 이후 사용자 지시로 별도 API 없는 로컬 합성 효과음 22종·33개 WAV를 적용했고, 사용자 제공 The_Final_Perimeter.mp3를 BGM으로 연결했다. 아래는 향후 음색 교체·추가 제작에 사용할 수 있는 프롬프트다.

## 공통 방향

- 차가운 병원, 고립감, 감염 위협. 과장된 공포 점프스케어보다 계속 이동하게 하는 긴장감.
- 보컬·대사·비명 없음. 특정 작품이나 음악가를 모방하지 않는 오리지널 사운드.
- 사격·경고음이 묻히지 않게 배경음의 중역을 비우고 과밀한 고역·과한 저음을 피한다.
- BGM: 약 60~100초의 자연스러운 루프. 시작·끝의 음색과 잔향이 이어지며 큰 도입부·엔딩 없음.
- SFX: 한 파일에 한 이벤트, 시작 전 공백 없음, 끝은 클릭 없이 자연스럽게 감쇠. 짧은 반복음은 3~5개 변형을 만든다.
- 납품 희망: BGM은 스테레오 OGG와 원본 WAV, 전투 SFX는 모노 WAV. 공간 환경음만 스테레오. 모두 48kHz, WAV는 PCM 16bit 이상.
- 아래 프롬프트의 구체적인 길이·루프·변형 개수는 생성 후 실제 파일에서 따로 검수한다.

## 배경음

### BGM 01 — 응급병동 / P0

사용: 1스테이지 180초 생존. 처음부터 지나치게 격렬하지 않은 긴장감.

```text
Create an original seamless looping instrumental soundtrack for a top-down hospital survival game. Location: an abandoned emergency ward under cold teal fluorescent lights. Mood: isolation, restrained dread, alertness, and steady forward movement. Tempo around 80 BPM. Use a soft analog bass pulse, a muted heartbeat-like rhythm, sparse metallic ticks, distant air-conditioning texture, and a short three-note minor-key motif. Gradually introduce subtle rhythmic detail while keeping the overall intensity controlled and consistent enough for repeated looping. Leave room in the midrange for frequent quiet syringe shots and clear enemy warning sounds. No vocals, speech, screams, loud medical alarms, jump scares, cinematic intro, or final cadence. Roughly 60–100 seconds, loop-ready with matching beginning and ending ambience and continuous reverb. Clean, original game music; no imitation of existing scores.
```

### BGM 02 — 격리병동 / P0

사용: 2스테이지 180초. 엘리트 등장과 살균 펄스로 전투가 커지는 구간.

```text
Create an original seamless looping instrumental combat track for an infected hospital isolation ward. Around 96 BPM, tense and propulsive but controlled. Develop the same restrained three-note minor-key identity as an abandoned emergency-ward theme. Add interlocking muted electronic percussion, a pulsing low synthesizer, short dry metal impacts, and a faint filtered air-pressure rhythm. The feeling is containment failure and increasing enemy pressure, not triumphant action. Keep sharp alarm-like pitches and the central midrange sparse so elite attack telegraphs remain easy to hear. Stable energy for a three-minute survival stage; no dramatic quiet breakdown or sudden volume jumps. No vocals, screams, speech, jump scares, long intro, or ending. Roughly 60–100 seconds, seamless rhythmic and reverb loop.
```

### BGM 03 — 수술동 감독관 / P0

사용: 3스테이지 중간 보스. 돌진·범위 공격의 예고음을 가리지 않는 전투곡.

```text
Create an original looping boss-battle soundtrack for a top-down hospital survival game. An enormous quarantine supervisor stalks a cold operating theatre. Around 112 BPM. Use a heavy but restrained mechanical bass pulse, dry industrial percussion, tense low strings or synthetic string textures, and fragmented versions of a short three-note minor-key motif. The rhythm should support dodging a telegraphed charge and returning to attack. Dangerous, clinical, focused, and relentless; not epic fantasy and not a loud wall of distortion. Leave clear spectral and rhythmic gaps for an 0.95-second charge warning and a short area-impact warning. No vocals, screams, spoken announcements, sirens, abrupt volume spikes, cinematic intro, or final cadence. Roughly 60–100 seconds, seamless loop with consistent intensity and matching reverb tails.
```

### BGM 04 — 감독관 폭주 레이어 / P1

사용: 보스 체력 50% 이하. BGM 03과 같은 템포·조성·박자에 얹는 보조 트랙. 원곡과 박자를 맞출 수 있을 때 채택.

```text
Create a sparse additive intensity layer for an existing 112 BPM minor-key hospital boss loop. Only tight mechanical hi-hat subdivisions, a low pulsing tension texture, and occasional restrained metallic accents. No main melody, no full drum kit, no new bass line, no vocals, no alarm sounds. It must increase urgency when mixed quietly over the base boss track without masking combat telegraphs. Start on the downbeat, keep constant tempo and bar structure, and make a seamless loop. Supply this as an isolated layer with no base soundtrack mixed in.
```

### BGM 05 — 타이틀 / P1

```text
Create a quiet seamless instrumental menu loop for a game called Endless Ward. Cold hospital air, a sparse felt-piano-like three-note minor motif, soft analog pads, very distant metallic room resonance, and a slow almost inaudible pulse. An invitation to enter a mysterious abandoned hospital, with restrained unease rather than immediate terror. No combat drums, vocals, dialogue, screams, loud alarms, jump scares, big intro, or ending cadence. Roughly 45–75 seconds, clean seamless loop, with enough silence between musical gestures for menu sound effects.
```

## 전투 효과음

### SFX 01 — 자동 주사기 발사 / P0 / 0.10~0.16초

```text
Create one short sci-fi medical syringe-injector shot: a tight pressurized air pfft, a tiny precise metal mechanism click, and a soft glassy tick. Crisp and readable but gentle enough to repeat several times per second. No firearm explosion, bullet shell, booming bass, voice, room ambience, or long reverb. Immediate onset, very short clean decay, approximately 0.12 seconds. Mono. Provide five subtly different takes with similar duration and loudness, one shot per file.
```

### SFX 02 — 적 명중 / P0 / 0.12~0.20초

```text
Create a compact enemy-hit sound for a stylized hospital survival game: a dry muted body thud layered with a tiny cloth snap and a subtle synthetic impact tick. Clear confirmation that a syringe projectile connected. No gore, squelching excess, scream, explosion, background noise, or long echo. Immediate attack, approximately 0.16 seconds, mono. Four small variations at consistent loudness, one hit per file.
```

### SFX 03 — 일반 적 처치 / P1 / 0.20~0.35초

```text
Create a short stylized infected-enemy defeat sound: a low soft impact, collapsing hospital fabric, and a faint downward electronic air release. Heavier than a normal hit but still quiet and compact during crowded combat. No human cries, horror scream, wet gore, spoken words, or long reverberation. Approximately 0.28 seconds, mono, three variations, one defeat per file.
```

### SFX 04 — 플레이어 피격 / P0 / 0.18~0.30초

```text
Create a distinct player-damage cue for a top-down hospital game: one tight low impact with a short brittle electronic crack and a small descending pitch gesture. It must be clearly different from enemy-hit sounds and readable over frequent injector shots, without being painfully loud. No voice, scream, medical siren, sustained ringing, or long tail. Immediate attack, approximately 0.24 seconds, mono. One damage event.
```

### SFX 05 — 경험치 획득 / P0 / 0.06~0.12초

```text
Create a very short soft experience-pickup sound: a rounded glass bead tick and a restrained teal-colored electronic sparkle, light and satisfying. It will play in clusters, so avoid harsh high frequencies, long sustain, wide pitch sweeps, or dense overlapping reverb. No coin clatter, voice, background noise, or melody. Approximately 0.09 seconds, mono. Five closely related pitch variations, one pickup per file.
```

### SFX 06 — 레벨업 / P0 / 0.60~0.90초

```text
Create a short level-up confirmation for a clinical sci-fi survival game. Three clean ascending soft synth notes, a subtle glass resonance, and a restrained warm low pulse. Communicate a useful improvement and brief relief while preserving the game's tense hospital atmosphere. Not a cheerful arcade fanfare. No vocals, long melody, big orchestral flourish, alarm, or background ambience. Approximately 0.75 seconds, clean natural ending.
```

### SFX 07 — 살균 펄스 / P0 / 0.45~0.80초

```text
Create a radial sterilization-pulse ability sound: a quick pressurized charging click followed immediately by a smooth expanding low electronic whoosh, a delicate crystalline ring, and a fast clean fade. The feeling is sterile energy moving outward through a hospital room. Powerful but not explosive, and comfortable to repeat every 3.2 seconds. No continuous hum, alarm, crackling fire, voice, or heavy sub-bass boom. Approximately 0.65 seconds, mono, one activation.
```

## 엘리트·보스 효과음

### SFX 08 — 엘리트 범위 공격 예고 / P0 / 0.85초

```text
Create an unmistakable elite area-attack warning lasting exactly 0.85 seconds. Three restrained dry mechanical pulses accelerate slightly into a short rising electronic tension tone. Clinical danger, clear timing, easy to recognize among injector shots. No impact at the end: the impact is a separate audio file. No medical-monitor imitation, voice, scream, deafening alarm, or reverb that extends beyond the warning window. Mono, immediate onset, one warning event.
```

### SFX 09 — 감독관 돌진 예고 / P0 / 0.95초

```text
Create a boss charge telegraph lasting exactly 0.95 seconds. A low heavy mechanical lock engages, followed by a tight rising pressure whine and two clear synchronized ticks. This means a huge enemy has locked its direction and is about to rush. Make it audibly different from a lighter elite area warning. No actual charge movement, collision, voice, siren, scream, or long tail. Clear start and precise finish, mono, one warning event.
```

### SFX 10 — 감독관 돌진 / P0 / 0.50~0.60초

```text
Create a short heavy creature-mechanical rushing sound for a large quarantine boss dashing across a hospital operating theatre. A fast low air-pressure rush with restrained boot-and-fabric friction, starting immediately and tapering quickly. Momentum without an explosion. Do not include the preceding warning or the ending collision. No voice, roar, scream, siren, or sustained ambience. Approximately 0.55 seconds, mono.
```

### SFX 11 — 범위 공격 착지 / P0 / 0.25~0.45초

```text
Create one controlled heavy area-impact sound on a hospital tile floor: a tight low body slam, a dry ceramic-and-metal snap, and a very short room tail. Weighty enough to distinguish a boss or elite slam from ordinary enemy hits, but not a cinematic explosion. No preceding charge-up, debris shower, voice, scream, alarm, clipping, or extended rumble. Approximately 0.35 seconds, mono.
```

### SFX 12 — 보스 폭주 전환 / P1 / 1.0~1.5초

```text
Create a single ominous boss-enrage transition cue: a deep mechanical latch breaking, a short descending dark tonal hit, then a compact rising pressure texture. The signal means the quarantine supervisor has become faster at half health. Menacing and clear, without being louder than necessary. No spoken announcement, roar, scream, alarm siren, long musical phrase, or continuous loop. Approximately 1.2 seconds with a clean finish.
```

## 환경·전환·UI

### SFX 13 — 병원 환경음 / P1 / 30~60초 루프

```text
Create a subtle seamless stereo ambience loop inside an empty abandoned hospital: low ventilation airflow, faint fluorescent electrical hum, distant building creaks, and very occasional quiet metal settling. Claustrophobic but believable, with no directional event that sounds like an enemy warning. No voices, footsteps, crying, screams, heart-monitor beeps, sirens, music, startling bangs, or obvious repeating pattern. Approximately 30–60 seconds with an imperceptible loop join. Keep the texture quiet and spectrally light for layering beneath game music.
```

### SFX 14 — 병동 클리어 / P1 / 1.2~1.8초

```text
Create a short restrained stage-clear cue for a tense hospital survival game. A three-note resolving electronic motif, a soft clean air release, and a quiet mechanical door-unlock click. Brief relief with the suggestion that another dangerous ward lies ahead. No celebratory orchestra, applause, speech, vocals, or long ending. Approximately 1.5 seconds. This is an intermediate stage-clear cue, not the final victory.
```

### SFX 15 — 감독관 처치·캠페인 완료 / P1 / 2~3초

```text
Create an original short final-victory stinger for a dark hospital survival game. A heavy low mechanism powers down, the tension releases, and a sparse three-note motif resolves into a restrained hopeful chord with a soft glass tail. Earned relief rather than exaggerated celebration. No voice, applause, scream, siren, or full song. Approximately 2.5 seconds, one complete event with a natural decay.
```

### SFX 16 — 패배 / P1 / 1~1.6초

```text
Create a short game-over cue: a soft low impact, a descending filtered synth phrase, and a quick fading air texture. Communicate failure and a prompt to try again, preserving the quiet clinical horror atmosphere. Avoid harsh punishment, screaming, flatline heart-monitor imitation, voice, or long silence at the start. Approximately 1.3 seconds with a clean short tail.
```

### SFX 17 — 메뉴 선택·확인 / P2 / 0.04~0.12초

```text
Create a small matching pair of understated clinical sci-fi UI sounds. Select: one soft dry tactile tick, about 0.05 seconds. Confirm: a slightly warmer double-layer glass-and-electronic click, about 0.10 seconds. Crisp, calm, and readable at low volume. No coin sounds, keyboard typing, voice, melody, background noise, or long reverb. Deliver each as a separate mono file.
```

## 적용할 때의 우선순위

1. P0: 응급·격리·보스 BGM, 발사·명중·피격·경험치·레벨업·펄스, 엘리트 예고·돌진 예고·돌진·착지.
2. P1: 처치·환경음·폭주·타이틀·병동 클리어·최종 완료·패배.
3. P2: 메뉴음 세분화, 소품·문·발소리. 자동 이동·사격 중 불필요한 소리를 늘리지 않는다.

배경음은 전투 효과음보다 낮게 시작하고, 공격 예고음이 들릴 때 잠깐 더 낮춘다. 새 병동 BGM은 약 1~2초 크로스페이드한다. 일시정지·포커스 상실 시 재생도 멈추고 M 음소거에 배경음·효과음을 함께 연결한다. 반복 발사·경험치 소리는 동시 재생 수를 제한하고, 실제 플레이에서 경고음을 식별할 수 있는지 확인한다.
