# agent-camp

[English](README.md) · 한국어

agent-camp은 하네스(코딩 에이전트 CLI)와 그 ACP 어댑터, [herdr](https://herdr.dev)를
[nix-basecamp](https://github.com/ajchemist/nix-basecamp) 위의 Home Manager
모듈로 설치합니다. yes라고 답하지 않은 것은 아무것도 설치하지 않습니다.

```
nix-basecamp   nixpkgs, Home Manager / nix-darwin 빌더
agent-camp     하네스 + ACP 어댑터 + herdr, 그리고 이들이 쓰는 bun/fnm/uv
emacs-camp     agent-shell이 어댑터와 통신 (CI가 agent-camp를 사용)
여러분의 flake 어떤 하네스를 쓸지, herdr 설정, 에이전트 설정 파일
```

## 하네스

| bin | 설치 방식 | ACP 어댑터 (`<bin>-acp`) | herdr hook |
|---|---|---|---|
| claude | `bun add -g @anthropic-ai/claude-code` | `claude-agent-acp` | 있음 |
| codex | `bun add -g @openai/codex` | `codex-acp` | 있음 |
| pi | `bun add -g @earendil-works/pi-coding-agent` | `pi-acp` | 있음 |
| omp | `bun add -g @oh-my-pi/pi-coding-agent` | 없음 | 있음 |
| goose | nixpkgs `goose-cli` | 내장 (`goose acp`) | 없음 |
| kimi | `uv tool install kimi-cli` | 내장 (`kimi acp`) | 있음 |
| hermes | 직접 설치 | 없음 | 있음 |

하네스는 거의 매일 릴리스되므로 버전을 고정하지 않습니다. switch할 때마다
`<pkg>@latest`를 실행하고, 이미 최신이면 아무 일도 하지 않습니다. ACP 어댑터는
에디터(Emacs의 agent-shell, Zed)가 하네스와 통신하는 데 쓰는 별도 패키지라서
답도 따로 받습니다.

## 무엇이 설치되나

모듈을 import하면 bun(nixpkgs보다 앞선 버전으로 고정), fnm과 LTS node 하나,
uv가 설치됩니다. 각 하네스와 각 어댑터는 호스트마다 다음 순서로 결정됩니다.

1. downstream이 Nix 옵션을 설정했다면 그 값을 따릅니다:
   `agent-camp.harnesses.<bin>.enable`, `agent-camp.harnesses.<bin>.acp`(`true`/`false`).
   이름을 바꾸기 전의 `agent-camp.agents`도 경고와 함께 계속 동작합니다.
2. 옵션이 없으면 `~/.config/agent-camp/harnesses`에 적힌 호스트의 답을 따릅니다
   (`claude=yes`, `claude-acp=no`처럼 한 줄에 하나). 예전 `~/.config/agent-camp/agents`는
   ask 스크립트가 한 번 이 경로로 옮깁니다.
3. 답이 없으면 설치하지 않습니다.

답은 `agent-camp-ask`(`lib.ask`)가 받습니다. downstream의 `nix run` 앱이 빌드
전에 실행하는 체크리스트입니다. 아직 답하지 않은 항목만 보여 주고 미리 선택된
항목은 없으며, 선택하지 않은 항목은 `no`로 기록됩니다. 터미널이 없으면 묻지도
기록하지도 않으므로, 비대화형 실행에서는 옵션이 강제한 것만 설치됩니다.

herdr는 opt-in입니다. `agent-camp.herdr.enable = true`로 켜면 릴리스 바이너리,
`agent-camp.herdr.plugins`에 커밋으로 고정한 플러그인, 그리고 설치된 하네스마다
integration hook이 설치됩니다. hook이 있어야 herdr 서버를 다시 시작했을 때 각
하네스의 세션이 이어집니다. herdr의 `config.toml`은 downstream이 관리합니다.

## 큐레이션 에이전트

agent-camp가 제공하는 서브에이전트 프로필입니다. 각각 `curated-agents/`에 원본이 하나씩 있고,
하네스마다 변환되어 설치됩니다([ADR 0003](docs/adr/0003-curated-agents.md)).

| 에이전트 | 설명 | 기본 하네스 |
|---|---|---|
| `ponytail` | [ponytail](https://github.com/DietrichGebert/ponytail)의 스킬을 스킬로 설치하지 않고, 고정된 store 경로에서 읽어 따르는 시니어 엔지니어 | claude, codex |

```nix
agent-camp.curated-agents.ponytail.harnesses.kimi = true;  # ~/.agents/agents/ponytail.md도 설치
agent-camp.curated-agents.ponytail.enable = false;         # 아예 설치하지 않음
```

파일 위치: claude `~/.claude/agents/<name>.md`, codex `~/.codex/agents/<name>.toml`,
kimi `~/.agents/agents/<name>.md`. pi는 본체에 서브에이전트가 없어서 아직 설치하지 않습니다.

## 사용법

```nix
inputs.agent-camp = {
  url = "github:ajchemist/agent-camp";
  inputs.basecamp.follows = "basecamp";
};

# Home Manager 설정 안에서
imports = [ agent-camp.homeModules.default ];
agent-camp.herdr.enable = true;
agent-camp.harnesses.claude = { enable = true; acp = true; };  # 선택: 묻지 않고 강제
```

downstream 앱에서는 다음 두 가지를 씁니다.

- 빌드 전: `${agent-camp.lib.ask { inherit pkgs; }}/bin/agent-camp-ask`
- 읽기 전용 상태 행: `${agent-camp.lib.plan { inherit pkgs; harnesses = …; herdr = …; }}/bin/agent-camp-plan`
  (모듈에 준 설정과 같은 값을 넘깁니다)

모듈이 답 파일을 읽을 수 있도록 home은 `--impure`로 평가합니다. 평가 시점에 답이
필요한 것은 nixpkgs로 설치하는 하네스(goose)뿐입니다.

## 대체되는 사본

모듈이 설치하는 것은 다른 설치 방법이 호스트에 남긴 사본을 대체합니다. switch할
때 다음을 지웁니다: 직접 설치한 `~/.bun/bin/bun`, `~/.nvm`, fnm의 예전 macOS 경로,
hermes의 node shim, uv standalone 바이너리, fnm node 아래의 전역 npm 하네스
사본, Claude Code 네이티브 설치본, goose 다운로드 스크립트가 넣은 바이너리, 직접
설치한 `~/.local/bin/herdr`.

## CI

`.github/workflows/ci.yml`은 Ubuntu와 macOS에서 실행됩니다.

- **check**: 모든 output이 평가되는지 확인합니다. 그다음 무엇이든 배포하기 전에,
  시스템마다 자기 check(`checks.nix`)를 전부 빌드합니다.
  - 실제 Home Manager / nix-darwin 빌드 안에서의 모듈
  - 모듈이 생성하는 activation 단계에 대한 shellcheck
  - 답 파일 로직(`choice.sh`)
  - 모듈만 import하면 하네스도 herdr도 설치되지 않는지, 알 수 없는
    하네스는 거부되는지
  - ask, plan 스크립트
- **deploy**: 두 시스템 모두 check를 통과해야 실행됩니다. `lib.ciSettings`로
  claude, codex, pi, goose와 각각의 어댑터, herdr를 runner에 배포합니다. 모든 명령이
  실행되어야 하고, 각 ACP 에이전트가 initialize를 마쳐야 합니다
  (`ci/acp-initialize.py`). 두 번째 배포도 성공해야 하고, 그 결과를 plan이 읽습니다.

emacs-camp CI도 같은 구성을 배포한 뒤 각 어댑터를 agent-shell로 구동해 봅니다.
