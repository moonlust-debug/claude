---
name: code-video
description: 코드로 애니메이션을 짜서 MP4 영상으로 뽑는다. 제품 소개 영상, 모션그래픽, 설명 영상, 쇼츠·릴스용 세로 영상, 로고 인트로, 데이터 시각화 영상처럼 "영상 만들어", "애니메이션 영상", "mp4로 뽑아", "모션그래픽", "쇼츠 영상" 같은 요청에 쓴다. HTML/CSS/Canvas/SVG(필요하면 GSAP·Three.js)로 장면을 만들고, 프레임을 한 장씩 캡처해 ffmpeg 로 인코딩한다. 실사 촬영 영상 생성이나 기존 영상 편집에는 쓰지 않는다.
---

# 코드로 영상 만들기

Opus 5.5 로 화제가 된 영상들은 전부 "영상을 코드로 짜고, 그 코드를 렌더링"한 결과다.
이 스킬은 그 흐름을 재현 가능한 절차로 고정한다.

## 순서

### 1. 기획을 한 줄로 고정
코드를 쓰기 전에 아래를 정해서 사용자에게 한 번에 보여 준다. 사용자가 이미 말한 것은 묻지 않는다.
- **비율**: 가로 16:9(1920×1080) 기본. 쇼츠·릴스·틱톡은 9:16(1080×1920), 정사각 1:1(1080×1080).
- **길이**: 기본 10~20초. 쇼츠는 15~30초.
- **방향**: 한 문장으로 된 미감("검은 배경에 거대한 세리프 한 줄", "70년대 인쇄 광고"). 디자인 스킬
  (`aura-farming`, `design-taste-frontend` 등)이 있으면 그 규칙을 따른다.
- **장면표**: 장면별 시작 초·길이·화면에 나오는 것. 장면은 3~7개.

### 2. 페이지 작성
`assets/template.html` 을 작업 폴더로 복사해서 시작한다. 지켜야 할 규칙:
- 화면의 모든 상태는 **시간 t(초)의 순수 함수**다. `window.renderFrame(t)` 하나가 t 를 받아
  모든 요소의 위치·투명도·크기를 정한다. `setTimeout`, `requestAnimationFrame`, 시드 없는
  `Math.random()` 금지. 그래야 프레임 단위로 멈춰서 찍어도 결과가 같다.
- 총 길이는 `window.DURATION` 에 초 단위로 적는다.
- GSAP 을 쓰면 `renderFrame` 없이 타임라인만 만들어도 된다. 렌더러가
  `gsap.globalTimeline` 을 멈추고 t 로 이동시킨다. CSS 애니메이션도 같은 방식으로 처리된다.
- 외부 이미지·폰트를 비동기로 불러오면 시작할 때 `window.READY = false`, 다 되면 `true`.
- 크기는 `vw`/`vh` 로 잡아 비율을 바꿔도 깨지지 않게 한다.
- 장면 전환은 겹쳐서(이전 장면 퇴장 0.3~0.6초와 다음 장면 등장이 겹침) 끊김 없이.

### 3. 미리보기 확인
전체 렌더 전에 핵심 시점 몇 장만 찍어 본다. 장면마다 중간 지점 하나씩이면 충분하다.
```bash
node -e "
const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();
const p=await b.newPage({viewport:{width:1920,height:1080}});
await p.goto('file://'+process.argv[1],{waitUntil:'networkidle'});
for(const t of process.argv.slice(2)){await p.evaluate(t=>window.renderFrame(+t),t);
await p.screenshot({path:'preview-'+t+'.png'});}await b.close();})()" "$PWD/video.html" 1 3 5
```
캡처를 직접 열어 보고 글자 잘림·겹침·빈 화면이 있으면 고친 뒤 다음 단계로.

### 4. 렌더
```bash
node <이 스킬 경로>/scripts/render.mjs video.html out.mp4 --fps 30 --width 1920 --height 1080
# 세로 쇼츠
node <이 스킬 경로>/scripts/render.mjs video.html out.mp4 --width 1080 --height 1920
# 배경 음악 (영상 길이에 맞춰 잘림)
node <이 스킬 경로>/scripts/render.mjs video.html out.mp4 --audio bgm.mp3
```
렌더러는 프레임마다 시간을 정확히 i/fps 로 맞추고 캡처하므로, 느린 머신에서도 프레임이 빠지지 않는다.

### 5. 검증
- `ffprobe -v error -show_entries format=duration:stream=width,height,r_frame_rate -of default=nw=1 out.mp4`
  로 길이·해상도·fps 가 기획과 맞는지 확인한다.
- 렌더된 영상에서 몇 장을 뽑아 직접 본다:
  `ffmpeg -v error -ss 2 -i out.mp4 -frames:v 1 check.png`

### 6. 저장
`D:\claude` 저장소에서 쓰는 중이면 결과 MP4 를 `videos/YYYY-MM-DD-<설명>.mp4` 로 두고
저장소 규칙대로 커밋·PR·머지한다. 페이지 HTML 은 같은 이름의 `.html` 로 함께 남겨 다시 렌더할 수 있게 한다.

## 의존성
- **ffmpeg**, **Node.js**, **Playwright + Chromium**.
- 웹 세션 컨테이너에는 모두 있다(ffmpeg 는 SessionStart 훅이 설치).
- Windows PC 에 없으면: `winget install ffmpeg`, `npm i -g playwright`, `npx playwright install chromium`.

## 결과 보고
완성 영상 파일, 장면표(초 단위), 사용한 방향 한 줄, 다시 렌더하는 명령.
