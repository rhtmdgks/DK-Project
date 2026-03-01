# TalkToFigma MCP (Grab) — 설정 및 사용

[grab/cursor-talk-to-figma-mcp](https://github.com/grab/cursor-talk-to-figma-mcp)는 Cursor와 Figma를 **WebSocket + Figma 플러그인**으로 연결하는 MCP입니다.  
Figma 공식 Desktop MCP와 달리 **선택/문서/노드 정보를 읽고, Figma를 수정**할 수 있습니다.

---

## 아키텍처

- **MCP 서버** (Cursor 쪽): `bunx cursor-talk-to-figma-mcp@latest`로 실행
- **WebSocket 서버**: `bun socket` — MCP와 Figma 플러그인 간 중계
- **Figma 플러그인**: 브라우저/데스크톱 Figma에서 실행 후 채널 접속

동작 순서: Cursor → MCP → WebSocket → Figma 플러그인 → Figma API

---

## 1. 사전 요구사항

- [Bun](https://bun.sh) 설치:
  ```bash
  curl -fsSL https://bun.sh/install | bash
  ```

---

## 2. 프로젝트 MCP 설정

프로젝트 루트 `.cursor/mcp.json`에 TalkToFigma가 이미 추가되어 있으면 Cursor가 해당 MCP를 불러옵니다.

현재 프로젝트에서는 **MCP 서버만** `npx`로 실행하도록 설정해 두었습니다 (Bun 경로 없이 동작).

```json
{
  "mcpServers": {
    "TalkToFigma": {
      "command": "npx",
      "args": ["cursor-talk-to-figma-mcp@latest"]
    }
  }
}
```

- **WebSocket**은 별도 패키지(`cursor-talk-to-figma-socket`)이며 **Bun 필요** → 터미널에서 `bunx cursor-talk-to-figma-socket` 실행.
- (기존에 다른 MCP가 있으면 `TalkToFigma` 항목만 추가하면 됩니다.)

---

## 3. WebSocket 서버 실행 (포트 3055)

Figma와 통신하려면 **WebSocket 서버를 켜 둔 상태**여야 합니다.  
**Bun이 필요합니다** (WebSocket 패키지가 Bun으로 동작).

```bash
bunx cursor-talk-to-figma-socket
```

실행되면 `WebSocket server running on port 3055` 로그가 나오고, Figma 플러그인에서 **Connect**로 접속할 수 있습니다.  
(서버를 끄지 않으려면 해당 터미널을 닫지 말고 두거나, 백그라운드로 실행하세요.)

- 포트 지정 시: `bunx cursor-talk-to-figma-socket --port 3055` (기본값이 3055임)

---

## 4. Figma 플러그인

1. [Figma 커뮤니티 플러그인](https://www.figma.com/community/plugin/1485687494525374295/cursor-talk-to-figma-mcp-plugin) 설치  
   또는
2. **개발용 로컬 플러그인**: Figma → Plugins → Development → New Plugin → **Link existing plugin** → 클론한 repo의 `src/cursor_mcp_plugin/manifest.json` 선택

Figma에서 **Cursor MCP Plugin** 실행 후, 플러그인 UI에서 **채널 이름 입력 → Join**으로 WebSocket 서버에 접속합니다.

---

## 5. 사용 순서

1. **WebSocket 서버** 실행 (`bun socket`)
2. **Cursor**에서 해당 프로젝트 열기 (MCP 자동 연결)
3. **Figma**에서 디자인 파일 열고 **Cursor MCP Plugin** 실행 → 채널 조인
4. Cursor에서 **`join_channel`** 도구로 같은 채널 이름 사용 (또는 프롬프트에서 “Figma와 채널 연결” 요청)
5. 이후 아래 도구들로 디자인 읽기/수정

---

## 6. 주요 MCP 도구 (구현/디자인 읽기용)

| 도구 | 용도 |
|------|------|
| `join_channel` | Figma 플러그인과 같은 채널로 접속 (필수 1순서) |
| `get_document_info` | 현재 문서 개요 |
| `get_selection` | 현재 선택 노드 정보 |
| `read_my_design` | 현재 선택에 대한 상세 노드 정보 (파라미터 없음) |
| `get_node_info` | 특정 node ID의 상세 정보 |
| `get_nodes_info` | 여러 node ID 배열로 일괄 조회 |
| `export_node_as_image` | 노드를 이미지(PNG 등)로 내보내기 |
| `set_focus` | 특정 노드 선택 및 뷰포트 이동 |
| `set_selections` | 여러 노드 선택 |

### 텍스트/레이아웃/스타일

| 도구 | 용도 |
|------|------|
| `scan_text_nodes` | 텍스트 노드 스캔 (대용량 시 청크 옵션) |
| `set_text_content` / `set_multiple_text_contents` | 텍스트 일괄 변경 |
| `set_layout_mode` / `set_padding` / `set_item_spacing` | Auto Layout 설정 |
| `set_fill_color` / `set_stroke_color` / `set_corner_radius` | 스타일 변경 |
| `create_frame` / `create_rectangle` / `create_text` | 노드 생성 |
| `move_node` / `resize_node` / `clone_node` / `delete_node` | 레이아웃·구조 변경 |

---

## 7. 본 프로젝트 워크플로와의 관계

- **Figma Desktop MCP** (get_metadata / get_design_context / get_screenshot):  
  현재 환경에서는 metadata·design_context가 안내문만 반환해 **HEURISTIC_MODE**로 구현 중입니다.
- **TalkToFigma**:  
  WebSocket + 플러그인 연결 후에는 **`read_my_design`**, **`get_node_info`**, **`get_nodes_info`**로 선택/노드별 **구조화된 정보**를 받을 수 있어, 구현 시 ground truth로 활용할 수 있습니다.

따라서:

1. **TalkToFigma 사용 가능 시**:  
   Figma에서 화면/컴포넌트 선택 → Cursor에서 `read_my_design` 또는 `get_node_info(nodeId)` 호출 → 반환된 구조/스타일을 기준으로 구현 (→ **FULL_GROUND_TRUTH** 또는 **PARTIAL_CONTEXT**).
2. **TalkToFigma 미사용 또는 실패 시**:  
   기존 [FIGMA_MCP_WORKFLOW.md](./FIGMA_MCP_WORKFLOW.md)대로 스크린샷 + 수동 스펙으로 **HEURISTIC_MODE** 유지.

---

## 8. 도구가 보이지 않을 때 (오류 시 점검 순서)

TalkToFigma 도구(`join_channel`, `get_node_info` 등)가 Cursor에 **등록되지 않았다**고 나오면 아래 순서로 확인하세요.

1. **Bun 설치** (WebSocket용)
   ```bash
   curl -fsSL https://bun.sh/install | bash
   ```

2. **WebSocket 서버 실행 (포트 3055)** — 터미널 하나에서 계속 켜 두기
   ```bash
   bunx cursor-talk-to-figma-socket
   ```
   → `WebSocket server running on port 3055` 확인.

3. **Figma에서**
   - 해당 파일 열기 (예: [DK-Project](https://www.figma.com/design/88esc758WVidgfK2f6w19A/DK-Project?node-id=847-4858))
   - **Plugins → Cursor MCP Plugin** 실행
   - 채널 이름 입력 (예: `dk-project`) 후 **Join** 클릭

4. **Cursor 재시작**  
   `.cursor/mcp.json`을 수정했다면, MCP를 다시 불러오려면 **Cursor를 완전히 종료했다가 다시 실행**하세요.

5. 연결 후 Cursor에서
   - `join_channel`로 같은 채널 이름(예: `dk-project`) 사용
   - `get_node_info(nodeId: "847:4858")` 로 투표 페이지 노드 정보 조회 → 반환된 값을 기준으로 UI 구현

---

## 9. 참고 링크

- [GitHub - grab/cursor-talk-to-figma-mcp](https://github.com/grab/cursor-talk-to-figma-mcp)
- [Figma 커뮤니티 플러그인](https://www.figma.com/community/plugin/1485687494525374295/cursor-talk-to-figma-mcp-plugin)
