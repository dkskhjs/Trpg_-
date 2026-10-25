# 창백한 청수리 — Godot 버전

Godot 4.3 이상에서 실행되는 데스크톱/모바일용 버전입니다. 시나리오는 웹 버전(`../index.html`)과 같습니다.

## 실행
1. [Godot 4.3+](https://godotengine.org/download)를 받습니다(표준판, .NET 필요 없음).
2. Godot에서 **가져오기**를 누르고 이 폴더의 `project.godot`을 엽니다.
3. **F5**로 실행합니다.

조작: 마우스로 선택하거나, 숫자키 1~9로 선택지를 고릅니다. Esc를 누르면 창이 닫힙니다.

## 구조
| 경로 | 내용 |
|---|---|
| `scripts/game.gd` | 규칙 엔진(판정, 효과, 사상, 저장). UI와 분리되어 있습니다 |
| `scripts/main.gd` | 화면 구성과 입력 |
| `data/story.json`, `data/world.json` | 시나리오 데이터. **직접 고치지 말고** 아래처럼 생성합니다 |
| `fonts/` | 나눔명조 (SIL OFL 1.1, `OFL.txt` 참고) |
| `tests/simulate.gd` | 헤드리스 무작위 플레이 테스트 |
| `tests/screenshot.gd` | 화면 캡처 확인용 |

## 시나리오 고치기
시나리오의 원본은 `index.html`의 `STORY` 하나입니다. 웹 버전에서 고친 뒤 저장소 루트에서 아래를 실행하면 Godot용 JSON이 다시 만들어집니다.

```sh
npm install
npm run export
```

## 테스트
```sh
godot --headless --path godot --script res://tests/simulate.gd
```
무작위로 1,500판을 돌려 결말 분포, 방문하지 못한 노드, 막힌 노드를 출력합니다.

## 내보내기(빌드)
Godot 에디터에서 **프로젝트 → 내보내기**로 Windows, macOS, Linux, Android, 웹 빌드를 만들 수 있습니다.
처음 한 번은 에디터에서 내보내기 템플릿을 받아야 합니다.
