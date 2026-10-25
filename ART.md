# 창백한 청수리 — 아트 바이블

이미지 생성 모델(Midjourney, ChatGPT 이미지, Gemini, Stable Diffusion/Flux 등)로 초상화와 배경을 만들기 위한 지침입니다.
프롬프트는 영어로 썼습니다. 대부분의 모델이 영어 프롬프트를 더 정확하게 따르기 때문입니다.
특정 작가나 게임 이름은 넣지 않고 화풍의 특징만 묘사했습니다.

## 1. 공통 화풍

확정된 화풍은 **빈티지 선전 포스터 실크스크린**입니다(완성된 초상화 5장 기준).
모든 프롬프트 앞에 아래 **스타일 블록**을 붙이세요. 남은 그림을 만들 때는 완성된 초상화 한 장을 참고 이미지로 함께 넣으면 화풍이 가장 잘 맞습니다.

```
vintage propaganda poster, screen print, bold black ink outlines, limited palette of vermilion red,
burnt orange, olive green, charcoal and cream, rough diagonal brush streaks in the background,
halftone dots, worn cream paper texture with a thin paper border, dramatic side lighting,
rural North Korea 1990s–2000s, no text, no lettering, no watermark
```

- **색**: 주홍, 번트 오렌지, 올리브, 숯빛, 크림색 종이. 붉은색은 완장, 구호 천, 배경 사선에 씁니다.
- **창백**: 모든 그림 어딘가에 **잉크가 찍히지 않은 듯한 크림색·하얀 영역**이 있습니다. 인물이라면 손끝, 배지, 옷자락이 하얗게 비어 있습니다(완성된 정명수·주인공 초상화처럼). 장소가 강에 가까울수록 이 영역이 넓어집니다.
- **금지**:
  - 실존 지도자의 얼굴. 초상화 액자는 반드시 **얼굴 없이 하얗게** 그립니다.
  - 읽을 수 있는 글자. 구호판은 붉은 바탕에 알아볼 수 없는 붓질로만 그립니다.
  - 국기와 실제 휘장.

| 모델 | 팁 |
|---|---|
| Midjourney | 끝에 `--ar 3:4 --style raw --stylize 250`(초상화), `--ar 16:9`(배경)를 붙입니다. 첫 결과가 마음에 들면 `--sref <이미지 URL>`로 이후 그림의 화풍을 고정합니다 |
| ChatGPT / Gemini | 첫 이미지가 나오면 "같은 화풍으로 다음 인물"이라고 이어서 요청하면 일관성이 유지됩니다 |
| SD / Flux | 네거티브 프롬프트: `text, letters, watermark, flag, photo, 3d render, anime, smooth digital art` |

## 2. Gemini로 바로 만들기

`ART.md`의 표가 곧 그림 목록입니다. 아래 스크립트는 이 문서의 표에서 `id`와 프롬프트를 읽고, 1장의 스타일 블록을 앞에 붙여 Gemini 이미지 API로 그림을 만든 뒤 게임 폴더에 넣습니다.

```sh
export GEMINI_API_KEY=...                       # 세션 환경 변수로 넣어두면 생략
python3 tools/gen_art.py --list                 # 목록과 완성 여부 보기
python3 tools/gen_art.py --missing              # 아직 없는 그림 전부 만들기
python3 tools/gen_art.py choi elder monument    # 골라서 만들기 (있으면 덮어씀)
python3 tools/gen_art.py --dry-run choi         # 보낼 프롬프트만 확인
```

- **초상화**는 완성된 주인공 초상화를, **배경**은 완성된 광장 그림을 참고 이미지로 함께 보내서 화풍을 맞춥니다.
- 결과물 위치:
  - 초상화: `godot/art/portraits/<id>.webp`
  - 배경: 원본은 `art_src/backgrounds/`, 블러 버전은 `godot/art/scenes/`
  - 소지품: `godot/art/items/<id>.webp`
- 새 초상화는 물감 방울 자리를 잡아야 색이 돌아옵니다. 자리를 잡기 전에는 흑백으로만 보입니다.
- 모델을 바꾸려면 `GEMINI_IMAGE_MODEL` 환경 변수를 쓰세요(기본: `gemini-2.5-flash-image`).

## 2-1. 규격과 파일 위치

| 종류 | 비율 | 권장 크기 | 저장 위치 |
|---|---|---|---|
| 인물 초상화 | 3:4 세로 | 896×1200 | `godot/art/portraits/<id>.webp` |
| 장소 배경 | 16:9 가로 | 1920×1080 | `godot/art/scenes/<id>.webp` |

파일 이름을 표의 `id`대로 맞추면 Godot에서 자동으로 연결됩니다. 초상화는 인물이 말할 때 왼쪽 패널에 뜹니다(`godot/scripts/main.gd`의 `PORTRAITS`).

## 3. 등장인물 초상화

공통 구도: `bust portrait, three-quarter view, face lit from one side`

완성: `hero` `park` `myeongsu` `oh` `cat` `mun` `yoon` `cheol` `kimsh` ✅ · 남은 것: `choi` `elder` · 5일째 세력 인물: `do` `kwak` `seo` `heo` `kang` `baek`

사물 초상화: `leader_portrait`(금테 액자 안이 하얗게 빈 수령님 초상화) ✅. 초대소에서 초상화를 살피는 장면에서 인물 초상화 대신 뜹니다(`main.gd`의 `NODE_PORTRAITS`).

게임에서는 초상화를 **흑백으로 바꾸고, 손·소품·얼굴 근처 몇 군데에만 물감을 떨어뜨린 것처럼 원래 색이 돌아오게** 보여줍니다(`godot/shaders/portrait.gdshader`). 창백 노출이 쌓이면 방울이 줄어듭니다. 방울 자리는 `godot/scripts/main.gd`의 `PORTRAITS`에서 정하고, `python3 tools/tone_preview.py`로 미리 볼 수 있습니다. 새 초상화를 넣으면 방울 자리를 잡아야 하니 알려주세요.

| id | 인물 | 프롬프트 (스타일 블록 뒤에 붙임) |
|---|---|---|
| `hero` | 주인공. 이름 없는 국가보위성 소좌, 45세 | `a gaunt 45-year-old Korean state security major, sharp cheekbones, unshaven, bloodshot tired eyes, olive military uniform with a small round lapel badge that has faded to blank white, hungover, haunted expression, one fingertip pale white` |
| `park` | 박순녀. 인민반장, 50대 | `a stern Korean woman in her 50s, neighbourhood watch leader, faded padded jacket, bright red armband, holding a straw broom, hair tied back, suspicious eyes hiding worry` |
| `myeongsu` | 정명수. 19세 하전사 | `a skinny 19-year-old Korean soldier, oversized olive uniform, rifle on shoulder, cracked lips, thousand-yard stare, the hem of his uniform and his hands fading into translucent white` |
| `oh` | 오영희. 기상관측원, 50대 | `a weary Korean woman in her 50s, meteorological observer, thick cardigan over work clothes, cigarette between fingers, smoke curling, ink-stained hands, dry sardonic half-smile` |
| `cat` | 고양이(김설화). 밀수꾼, 20대 | `a sharp-eyed Korean woman around 20, cropped hair, cheap Chinese puffer jacket, holding an old smartphone with a glowing screen, defiant cat-like gaze, backpack strap on shoulder` |
| `choi` | 최경철. 검열국 중좌, 50대 | `an imposing Korean lieutenant colonel in his 50s, long dark leather-trimmed greatcoat, red shoulder boards, cold authoritative face cracking with fear, one hand bare and completely white up to the wrist` |
| `elder` | 묘지기 노인. 70대 | `a bent old Korean man in his 70s, grave keeper, weathered deep-lined face, holding a sickle, patched cotton clothes, calm eyes that remember too much` |

### 4일째 이후 새 인물 (스타일 블록 뒤에 붙임)

| id | 인물 | 프롬프트 | 물감 방울 후보 |
|---|---|---|---|
| `mun` | 문봉식. 협궤 운전수, 50대. 1997년에서 늙지 않고 돌아옴 | `a weathered Korean railway engine driver in his 50s, outdated 1990s railway uniform with brass buttons and cap, holding a crumpled ration coupon, confused gentle eyes, white dust on his boots and shoulders` | 배급표, 제복 단추 |
| `yoon` | 윤해란. 중앙당 지도원, 30대 | `a sharp Korean woman in her mid 30s, central party official, black padded coat, small red badge on her chest, hair tied tightly, cold precise gaze, one coat button completely blank white` | 붉은 배지, 하얀 단추 |
| `cheol` | 리철(철이). 소년단원, 12세 | `a 12-year-old Korean schoolboy, red neckerchief of the children's union, school uniform, holding a worn class roll book, tired brave eyes, frost on his cap` | 붉은 넥타이, 출석부 |
| `kimsh` | 김선희. 혁명전적지 해설강사, 40대 | `a Korean woman in her 40s, revolutionary site tour guide, traditional-style uniform dress, pointer stick in hand, mouth mid-sentence, parts of her face and pointer fading into blank cream paper` | 지시봉 끝, 입술 |

## 4. 장소 배경

공통 구도: `wide establishing shot, no people in the foreground, eye level`

완성: `inn` `inn_night` `square` `square_pale` `rally` `river` `edge` `station` `market` `park_home` `graves` ✅ · 남은 것: `truck` `lockup` `finale` `dark` · 4일째 새 장소: `rail` `jeep_road` `bocheon` · 5일째 새 장소: `samjiyon` `monument` `pioneer_camp` `lab_tent` `bear_camp` `purge_post` `caravan_ice`

원본을 받으면 `python3 tools/prepare_backgrounds.py <폴더>`로 가공합니다. 원본은 `art_src/backgrounds/`에 보관되고, 블러를 먹인 버전이 `godot/art/scenes/`에 들어갑니다(블러 강도: `--blur 6`).
`scene` 열은 게임 속 장면 이름입니다(이 이름으로 배경을 매칭합니다).

| id | scene | 프롬프트 (스타일 블록 뒤에 붙임) |
|---|---|---|
| `inn` | 청수리 초대소 | `a bleak guesthouse room in a North Korean border village, thin bedding on the floor, cold coal stove, two empty liquor bottles, cracked mirror, two gilded portrait frames on the wall whose pictures are completely blank white` |
| `inn_night` | 초대소 · 밤 | `the same bleak guesthouse room at night, single dim bulb, window glowing with an eerie pale white light from outside` |
| `square` | 청수리 광장 (1~2일째) | `a small dirt village square, kimchi storage mounds, shuttered state shop, a loudspeaker on a wooden pole, a large red propaganda billboard with illegible faded strokes, northern sky beyond the roofs is solid blank white` |
| `square_pale` | 청수리 광장 · 3일째 | `the same village square, but its northern half has been erased into flat blank white canvas, villagers' bundles left on the ground, the loudspeaker on the pole is a white silhouette` |
| `rally` | 궐기대회 | `a village mass rally, crowd of sixty peasants with raised fists and red placards, a wooden podium with a man in a greatcoat, red banners, the white haze swelling at the far edge of the square as they shout` |
| `river` | 압록강 둑 | **실사진 사용** — 「North Korea and Yalu River」(Wikimedia Commons, CC BY 2.0). 가운데만 흐리게 가공(`prepare_backgrounds.py`의 CENTER). 만든이들 화면에 출처 표기. 생성용 옛 설명: `a riverbank on the Korean-Chinese border, barbed wire fence, a small guard post, the river flows but halfway across it the world ends in a silent flat white void, no far shore` |
| `river_beyond` | 압록강 너머 (창백이 그려진 풍경) | **보류 — 게임에서 뺐음, 새 그림 필요.** 이전 시안: 기획자가 직접 제공한 유화. 강 위에 고래 모양의 하얀 공백과 흩어지는 흰 점. 전용 셰이더(`bg_pale.gdshader`)로 일렁이고 빛나며, 처음 볼 때 막을 걷어 풍경을 먼저 보여준다. 블러 1.5 |
| `edge` | 창백의 경계 | `a village dirt road that simply ends in a wall of featureless white, faint silhouettes of people standing and waiting inside the white` |
| `station` | 기상관측소 | `a small concrete weather station on a hilltop, Stevenson screen, rusty wind vane and antenna, inside a cluttered desk with logbooks, an old valve radio, thick cigarette smoke` |
| `market` | 장마당 뒷골목 | `a deserted black-market alley, plastic tarps and empty wooden stalls, scattered Chinese cigarette packs, cold wind, grey light` |
| `park_home` | 박순녀의 집 | `a poor mud-walled farmhouse interior, kitchen hearth, one room, two blank white portrait frames on the wall, a straw broom by the door, a pair of soldier's boots in the corner` |
| `graves` | 뒷산 공동묘지 | `a bare hillside cemetery of low unmarked earth mounds scattered without order, a few wooden grave markers whose writing has faded to white, dry grass, overcast sky` |
| `truck` | 군용 트럭 | `an old olive military truck parked in the village square, canvas cover, mud-splattered, a figure in a greatcoat smoking beside it` |
| `lockup` | 초대소 구류실 | `a converted storage shed used as a holding cell, heavy rusted padlock that still has colour, thin light through plank gaps` |
| `finale` | 밤의 압록강 | `night at the border, an empty guard post table with a pencil and a blank report form, the white void now glowing faintly and lighting everything from the north` |
| `rail` | 협궤 철길 (4일째, 물러남) | `a rusted narrow-gauge railway along a frozen river, a small hand-pushed rail cart, patches of blank white haze left beside the tracks, faint factory lights of a Chinese city across the river` |
| `jeep_road` | 하얀 길 (4일째, 확장) | `a military jeep with a loudspeaker on its roof driving on a road that is solid blank white, only a few meters of grey road appear in front of its wheels, mountains fading into white` |
| `bocheon` | 보천 갈림길 (4일째 밤) | `a tiny abandoned mountain railway station at night, collapsed roof, wall clock stopped, small coal stove glowing, the northern sky beyond the window a tall silent white` |
| `samjiyon` | 삼지연 읍 (5일째) | `a small model mountain town under a tall silent white sky, neat identical houses, a frozen lake, snow that is too white, distant forested slopes of a great mountain` |
| `monument` | 삼지연 기념비 광장 | `a vast monument plaza with an enormous empty stone pedestal at the center, the statue missing, a ring of forty people in winter coats walking around it reciting, red banners with illegible strokes, the pedestal area blank white` |
| `pioneer_camp` | 답사숙영소 | `a large wooden dormitory room, thirty schoolchildren with red neckerchiefs sitting in a circle on the floor, one boy reading from a roll book, frost on the windows` |
| `lab_tent` | 연구소 천막 | `a research tent by a frozen lake, generator, analog gauges, dozens of glass jars filled with swirling white haze, labels on the jars illegible` |
| `bear_camp` | 곰쫓사 야영지 | `two canvas tents and a campfire burning mugwort at the edge of a forest, where blank white begins, huge bear footprints pressed into the white` |
| `purge_post` | 정리반 지휘소 | `army barracks with six oil drums burning boxes of documents, soldiers emptying files into the fire, thick white smoke rising and whitening the sky` |
| `caravan_ice` | 흰 길 상단 (얼음판) | `a frozen lake with twelve sleds tied together by ropes, smugglers in fur coats with name tags, heading toward a blank white horizon` |
| `dark` | 어둠 | `almost total darkness, the faint outline of a loudspeaker horn, a single sliver of white light` |

### 세력 인물 (5일째)
| id | 인물 | 프롬프트 |
|---|---|---|
| `do` | 도학수 교수. 단군신화 연구대장, 70대 | `an elderly Korean archaeologist in his 70s, round wire glasses, worn field jacket over a suit, holding an old bone fragment wrapped in cloth, guilt in his eyes, mountain cold on his breath` |
| `kwak` | 곽만석. 백두산 포수, 50대 | `a rugged Korean mountain hunter in his 50s, fur hat, old hunting rifle, snow on his shoulders, squinting at tracks in the snow` |
| `seo` | 서은하. 생물학 연구원, 20대 | `a young Korean woman biologist in her 20s, padded lab coat over winter clothes, specimen jars and a notebook, eager intense eyes` |
| `heo` | 허명진. 창백 연구소 연구사, 40대 | `a thin Korean physicist in his 40s, round glasses, padded lab coat, holding a glass jar filled with swirling blank white haze up to the light, curious and uneasy expression` |
| `kang` | 강동혁. 정리반장, 50대 | `a hard-faced Korean colonel in his 50s, military greatcoat, red shoulder boards, standing before an oil drum fire full of burning papers, white smoke rising behind him, expressionless` |
| `baek` | 백순자. 흰 길 상단 우두머리, 60대 | `a shrewd Korean-Chinese woman merchant in her 60s, thick fur coat and hat, sled rope coiled on her shoulder, wry smile, a name tag pinned to her coat` |
| `white_bear` | 하얀 곰 (장면 그림) | `a huge pale bear walking through a blank white snowfield, its fur the same color as the void, only its dark eyes and footprints visible` |

### 5일째 이후 예정 장소
삼지연 읍과 기념비 광장, 혁명전적지 해설관, 백두산 기슭 숲길, 밀영. 세력이 확정되면 연구소 천막, 연구대 야영지, 쑥 냄새 나는 동굴 입구, 하얀 곰 발자국이 찍힌 눈밭 등을 추가합니다.

## 5. 소지품 그림 (선택)
아이템 아이콘으로 쓸 수 있는 작은 그림입니다. 정사각형 512×512, 크림색 종이 바탕에 물건 하나만 그립니다.

| id | 물건 | 프롬프트 |
|---|---|---|
| `item_radio` | 휴대용 단파 라디오 | `a worn 1980s portable shortwave radio with a telescopic antenna and hand-modified dial, single object on cream paper` |
| `item_notel` | 노텔(휴대용 DVD 플레이어) | `a cheap Chinese portable DVD player with a small flip screen, scratched, single object on cream paper` |
| `item_dvd` | 「혁명가요 모음」 알판 | `a DVD in a plain paper sleeve with handwritten label, single object on cream paper, label illegible` |
| `item_phone` | 중국 손전화 | `an old cracked smartphone with a glowing screen, single object on cream paper` |
| `item_ledger` | 인민반 명단 | `a thin worn notebook with handwritten columns of names, some rewritten in fresh ink, single object on cream paper, writing illegible` |

## 6. 결말 일러스트 (선택)

| id | 결말 | 핵심 이미지 |
|---|---|---|
| `end_lie` | 공화국 영웅 | 이름 칸이 하얀 훈장 증서. 배경은 전부 하얗다 |
| `end_truth` | 기록하는 자 | 트럭 짐칸의 남자. 강 건너에 불빛 하나 |
| `end_truck` | 남쪽으로 가는 길 | 하얀 평면 위에 멈춘 군용 트럭 한 대 |
| `end_walk` | 국경 없음 | 강 한가운데의 하얀 공간에서 만난 두 병사 |
| `end_names` | 명부 | 숯으로 쓴 이름이 벽과 바닥을 덮은 초소 |
| `end_wake` | 이름을 쓰는 자 | 볼펜 홈을 따라 이름을 다시 쓰는 손 |

## 7. 작업 순서 제안
1. `hero`로 화풍을 먼저 확정합니다. 이 그림이 이후 모든 그림의 기준이 됩니다.
2. 나머지 인물 6명을 같은 화풍으로 만듭니다.
3. 배경은 1일째 장소부터 만듭니다: `inn` → `square` → `river` → `station` → `market`.
4. 2~3일째 장소와 결말 일러스트를 만듭니다.
