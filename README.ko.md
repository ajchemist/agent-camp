# agent-camp

[English](README.md)

agent-camp은 하네스(코딩 에이전트 CLI)와 그 ACP 어댑터, [herdr](https://herdr.dev)를
Home Manager 모듈로 설치합니다. yes라고 답하지 않은 하네스는 설치하지 않습니다. 하네스가 읽는
파일일 뿐인 큐레이션 에이전트와 user scope 스킬은 기본으로 켜져 있고, 끌 수 있습니다.

```
upstream       nixpkgs, Home Manager, nix-darwin (여러분의 flake.lock이 고정)
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
2. 옵션이 없으면 `~/.config/agent-camp/harnesses`에 적힌 호스트의 답을 따릅니다
   (`claude=yes`, `claude-acp=no`처럼 한 줄에 하나).
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
| `ponytail` | [ponytail](https://github.com/DietrichGebert/ponytail)의 스킬을 스킬로 설치하지 않고, 고정된 store 경로에서 읽어 따르는 시니어 엔지니어. 작업 트리를 직접 고치고, 메인 에이전트가 그 작업을 이어받음 | claude, codex |
| `designer` | DESIGN.md를 기준으로 타이포그래피·간격·레이아웃·모션을 맡는 디자인 엔지니어. 네 모드(reference, direction, build, critique)로 일하고, [Emil Kowalski](https://github.com/emilkowalski/skills)·[Impeccable](https://github.com/pbakaus/impeccable)·[Taste](https://github.com/Leonxlnx/taste-skill)·[GSAP](https://github.com/greensock/gsap-skills) 스킬과 자체 스킬을 읽음([ADR 0005](docs/adr/0005-designer.md)) | claude, codex |

```nix
agent-camp.curated-agents.ponytail.harnesses.kimi = true;  # ~/.agents/agents/ponytail.md도 설치
agent-camp.curated-agents.ponytail.replaceBuiltins = true; # 내장 코딩 서브에이전트도 대체 (kimi `coder`), 에이전트 하나만
agent-camp.curated-agents.ponytail.activation = "off";     # 아예 설치하지 않음 (활성화 참고)
```

파일 위치: claude `~/.claude/agents/<name>.md`, codex `~/.codex/agents/<name>.toml`,
kimi `~/.agents/agents/<name>.md`. pi는 본체에 서브에이전트가 없어서 아직 설치하지 않습니다.

ponytail을 만들고 검증한 과정:
[docs/curated-agent-workflow.md](docs/curated-agent-workflow.md). 하네스별로 무엇을
컨텍스트에 넣고 어떻게 뺄 수 있는지: [docs/harness-context.md](docs/harness-context.md).

### 활성화

설치된 에이전트는 그 위임 규칙(`curated-agents/<name>/delegation.md`)이 메인 에이전트의
지시문에 있고 켜져 있을 때만 위임받습니다. 모든 curated agent가 같은 방식으로 세 층에서
정해지고, 뒤의 층이 이깁니다: **세션 > 저장소 > 모듈**.

1. **모듈**, 배포할 때: `agent-camp.curated-agents.<name>.activation`.

   | 값 | 설치되는 것 | 규칙이 켜지는 곳 |
   |---|---|---|
   | `global` (designer 기본값) | 에이전트, 그리고 각 하네스의 사용자 수준 지시문에 그 규칙 | 모든 저장소. 저장소 `AGENTS.md`가 끄면 제외 |
   | `opt-in` (ponytail 기본값) | 같음 | 저장소 `AGENTS.md`가 켜거나, 규칙을 직접 담고 있는(예전처럼 붙여 넣은) 저장소만 |
   | `off` | 없음 | 없음 |

   예전 옵션 `enable = false`는 `"off"`와 같습니다.

   규칙은 각 하네스가 사용자 수준 지시문을 읽는 곳에 들어가되, 사용자가 쓰는 파일을
   차지하지 않습니다.

   - claude: `~/.claude/rules/agent-camp-curated-agents.md`, 모듈 전용 파일입니다. Claude
     Code는 사용자 규칙을 매 세션 `~/.claude/CLAUDE.md`와 함께 읽고, `CLAUDE.md`는 그대로
     사용자 것입니다.
   - codex: `~/.codex/AGENTS.md` 끝의 표시된 블록(`<!-- agent-camp curated agents: begin … end -->`).
     switch마다 다시 쓰고, 설치된 에이전트가 없으면 지웁니다. Codex는 이 파일 하나만 읽고
     다른 파일을 포함하지 않습니다. 블록 밖은 사용자가 쓴 그대로 두고, 블록 안을 고치면
     사라집니다. 파일이 링크이면(예: 공유하는 `~/.agents/AGENTS.md`로) 건드리지 않고 경고만
     내니, 링크가 가리키는 파일을 `sharedInstructions`(아래)로 지정하세요. `~/.codex/AGENTS.override.md`가 있으면
     블록째 `AGENTS.md`를 대신합니다.
   - kimi: 없음. kimi-cli는 프로젝트 안의 `AGENTS.md`만 읽으므로, kimi용으로 설치한
     에이전트는 `AGENTS.md`에 규칙을 담은 저장소에서만 쓰입니다.

   **공유 파일 하나**: 모든 하네스가 사용자가 쓰는 지시문 파일 하나를 읽는다면(예:
   `~/.agents/AGENTS.md`에 `~/.codex/AGENTS.md`는 심볼릭 링크로, `~/.claude/CLAUDE.md`는
   `@~/.agents/AGENTS.md`로 가져옴) 모듈에 그 파일을 알려 주세요:

   ```nix
   agent-camp.curated-agents.sharedInstructions = "~/.agents/AGENTS.md"; # 또는 절대 경로
   ```

   그러면 규칙은 그 파일에만, 끝의 같은 표시된 블록으로 들어갑니다. switch마다 다시 쓰고
   (블록 안을 고치면 사라짐), 설치된 에이전트가 없으면 지우며, 블록 밖은 그대로 둡니다.
   파일이 없으면 블록만 담아 만들고, 일반 파일이어야 합니다(링크이면 경고하고 건드리지
   않음). 모듈은 claude 규칙 파일도 `~/.codex/AGENTS.md` 블록도 쓰지 않고, 앞선 switch가
   쓴 것은 지웁니다. `~/.codex/AGENTS.md`가 공유 파일을 가리키는 링크인 것이 예상한 구성이라
   경고하지 않습니다. 공유 파일을 읽지 않는 하네스는 규칙을 받지 못합니다. 나중에 옵션을
   지워도 공유 파일의 블록은 남으니 직접 지우세요.

2. **저장소**: `AGENTS.md`의 한 줄. 모든 에이전트가 같은 모양입니다.

   ```
   curated-agents: designer off
   curated-agents: ponytail on
   ```

   규칙의 첫 문단이 메인 에이전트에게 이 줄을 따르라고 합니다. 모델이 따르는 규칙이지
   강제가 아닙니다. Claude Code에서 강제하는 방법은 저장소 `.claude/settings.json`의 deny
   규칙이고, 모델이 무엇을 읽든 Claude Code가 막습니다:

   ```json
   { "permissions": { "deny": ["Agent(designer)"] } }
   ```

   Codex와 kimi에는 에이전트별 deny가 없습니다.

3. **세션**: `AGENT_CAMP_DISABLE_AGENTS="designer,ponytail" claude` (쉼표나 공백으로 구분).
   모듈이 설치하는 세션 시작 훅(`~/.local/share/agent-camp/session-start`)이 이름마다
   "Do not delegate to the designer subagent in this session"을 출력하고, 하네스가 이를
   컨텍스트에 넣습니다. 끄기만 하고 켜지는 못합니다.

   - claude: `~/.claude/settings.json`의 `hooks.SessionStart`에, 아래 읽기 규칙과 같은
     방식으로 합칩니다. 시작, resume, `/clear`, 압축 때 실행됩니다.
   - codex: `~/.codex/hooks.json`의 `hooks.SessionStart`에 같은 방식으로 합칩니다. Codex는
     신뢰한 훅만 실행하므로, 첫 switch 뒤에 TUI에서 `/hooks`를 한 번 열어 신뢰해 주세요. 훅
     명령은 고정 경로라서, 스크립트 내용이 바뀌는 switch 뒤에도 신뢰가 유지됩니다.
   - kimi: 없음. kimi-cli는 SessionStart 훅을 실행하지만 출력을 버립니다.

   훅은 그 하네스로 가는 curated agent가 하나라도 있으면 설치됩니다.

| | 모듈 (사용자 수준 규칙) | 저장소 줄 | 강제 deny | 세션 변수 |
|---|---|---|---|---|
| claude | 예 | 예 | `Agent(<name>)` | 예 |
| codex | 예, `~/.codex/AGENTS.md`가 링크가 아니면(`sharedInstructions`면 링크도 됨) | 예 | 아니오 | 예, 훅을 신뢰한 뒤 |
| kimi | 아니오 | `AGENTS.md`에 규칙이 있을 때만 | 아니오 | 아니오 |

### Claude Code 읽기 규칙

Claude Code는 작업 폴더 밖의 파일을 읽기 전에 허락을 묻고, headless 실행(`claude -p`)에서는
거부합니다. 그래서 curated agent가 자기 스킬을 읽지 못할 수 있습니다. Claude Code로 가는
curated agent가 하나라도 있으면, switch가 `~/.claude/settings.json`의 `permissions.allow`에
`Read(//nix/store/**)`를 넣습니다. 이 파일은 Claude Code도 고쳐 쓰기 때문에 모듈이 통째로
관리하지 않습니다.

- `permissions.allow`만 바꿉니다. 지난번에 모듈이 넣은 규칙(`~/.local/state/agent-camp/claude-allow`에
  기록)을 빼고, 지금 필요한 규칙을 사용자 규칙 뒤에 넣습니다. 다른 키와 규칙은 그대로 둡니다.
- 규칙이 바뀔 때만 파일을 씁니다. Claude Code용 curated agent를 모두 끄면 규칙도 빠집니다.
- 세션 훅도 같은 방식으로 `hooks.SessionStart`에 들어가고(state: `claude-session-start`),
  Codex 훅은 `~/.codex/hooks.json`에 들어갑니다(`codex-session-start`).
- 파일이 링크이거나 JSON이 깨져 있으면 건드리지 않고 경고만 냅니다.

알아 둘 점:

- 쓸 때 파일 전체가 `jq`를 거치므로 포맷이 jq 형식(2칸 들여쓰기, Claude Code와 같음)이 됩니다.
- 규칙을 손으로 지우면 규칙 내용이 바뀌거나 state 파일을 지우기 전까지 다시 넣지 않습니다.
- 모듈과 같은 규칙을 직접 넣어 두었다면 모듈 것으로 취급되어, 모듈이 규칙을 뺄 때 같이 빠집니다.
- switch 도중 Claude Code가 이 파일을 쓰면 그 한 번의 변경이 덮어써질 수 있습니다.

## User scope 스킬

특정 저장소가 아니라 일하는 방식에 관한 스킬은 저장소마다 `skills-lock.json`이나
플러그인 설정에 넣지 않고 user scope에 둡니다([ADR 0004](docs/adr/0004-user-scope-skills.md)).
버전은 nix가 `skill-sources/<name>/source.nix`로 고정하고, 배치는
[skills CLI](https://github.com/vercel-labs/skills)가 합니다.
`skills add <store 경로> -g -a <agent>… -s <skill>…`가 각 스킬을 `~/.agents/skills`에
복사하고 나머지 에이전트에 symlink를 겁니다(전역 설치는 `claude-code` 하나만 골라도
`~/.agents/skills`에 둡니다).

| 소스 | 기본 스킬 | 기본 에이전트 |
|---|---|---|
| `mattpocock-skills` ([mattpocock/skills](https://github.com/mattpocock/skills)) | 안정된 engineering/productivity 스킬 27개 전체: grilling 등 워크플로 의존 스킬 포함 | `claude-code`, `codex` |

```nix
agent-camp.skills.mattpocock-skills.skills = [ "grill-me" "to-spec" ];       # 일부만
agent-camp.skills.mattpocock-skills.agents = [ "claude-code" "codex" "kimi-code-cli" ];  # skills CLI의 agent ID
agent-camp.skills.mattpocock-skills.enable = false;                          # 설치 안 함
```

워크플로 실행에 필요한 grilling, tdd, domain-modeling 등도 기본 설치합니다.
모델이 부르는 스킬은 모든 세션의 스킬 목록에 들어갑니다.
고정된 업스트림 파일은 Vercel skills CLI로 수정 없이 설치합니다.

**nix가 관리하는 것과 로컬에서 바꿀 수 있는 것**

- switch는 소스의 고정 버전, 스킬 목록, 에이전트 목록 중 하나가 바뀔 때만 그 소스에
  `skills add`를 다시 실행합니다(마지막 적용: `~/.local/state/agent-camp/skills/<name>`).
  그 사이에는 설치된 사본을 로컬에서 바꿔도 됩니다.
- 사본은 일부러 읽기 전용입니다. nix의 상태라는 표시입니다. 고치고 싶으면 그 자리에서
  고치지 말고 가져가세요: GitHub에서 `bunx skills add <owner/repo> -g -s <skill>`
  (이후 `bunx skills update -g`도 동작), 또는 `bunx skills remove -g <skill>` 후 직접 설치.
- 그 소스에 다음 nix 변경(bump나 옵션 수정)이 오면 소스를 다시 추가하면서 **가져간 스킬을
  고정 버전으로 덮어씁니다.** 계속 직접 관리하려면 `agent-camp.skills.<name>.skills`에서 빼세요.
- store 경로에서 온 스킬이 목록에서 빠지면 지워집니다. 다른 소스에서 온 스킬(lock 파일의
  `source`가 `/nix/store/…`가 아닌 것)은 건드리지 않습니다.

**소스별 보기 폴더: 디렉터리 하나를 통째로 받는 하네스용.** switch마다
`~/.local/share/agent-camp/skills/<name>/`을 다시 만듭니다. 그 소스의 스킬만
`~/.agents/skills`에서 가리키는 symlink 모음입니다. 파생물이라 고치지 않고, 지워도 잃는 것이
없습니다. hermes는 다른 에이전트의 디렉터리를 읽지 않고 프로필마다 홈이 따로라서, 각 프로필
(기본 프로필 포함)이 자기 `config.yaml`에서 opt-in합니다:

```yaml
skills:
  external_dirs: ["~/.local/share/agent-camp/skills/mattpocock-skills"]
```

## 사용법

```nix
inputs.agent-camp = {
  url = "github:ajchemist/agent-camp";
  # 모든 flake가 같은 pin을 쓰도록 자기 input에 묶음
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
  inputs.nix-darwin.follows = "nix-darwin";
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
  - 실제 Home Manager / nix-darwin 빌드 안에서의 모듈(`ci/fixture.nix`, upstream
    빌더 그대로)
  - 모듈이 생성하는 activation 단계에 대한 shellcheck
  - 답 파일 로직(`choice.sh`)
  - 모듈만 import하면 하네스도 herdr도 설치되지 않는지, 알 수 없는
    하네스는 거부되는지
  - curated agent의 activation마다 각 하네스의 사용자 수준 지시문과 훅 파일에 무엇이
    들어가는지
  - ask, plan 스크립트
- **deploy**: 두 시스템 모두 check를 통과해야 실행됩니다. `lib.ciSettings`로
  claude, codex, pi, goose와 각각의 어댑터, herdr를 runner에 배포합니다. 모든 명령이
  실행되어야 하고, 각 ACP 에이전트가 initialize를 마쳐야 합니다
  (`ci/acp-initialize.py`). 두 번째 배포도 성공해야 하고, 그 결과를 plan이 읽습니다.

emacs-camp CI도 같은 구성을 배포한 뒤 각 어댑터를 agent-shell로 구동해 봅니다.
