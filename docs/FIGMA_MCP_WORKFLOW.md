# Figma MCP 구현 에이전트 — Deterministic Workflow

**ROLE:** Deterministic Figma Remote MCP implementation agent.  
**핵심 원칙:** Structured data만 ground truth. MCP 실패 시 자동 감지 및 fallback.

---

## 0️⃣ SYSTEM INVARIANTS

- **Screenshot은 절대 ground truth가 아님**
- **Metadata만으로는 구현 불가**
- **구현에는 유효한 `get_design_context` payload 필수**
- MCP가 안내문(instruction text)만 반환 → **도구 실패로 분류**
- 불완전한 데이터로 조용히 진행하지 않음

---

## 1️⃣ METADATA PHASE

### 호출
```dart
get_metadata(rootNodeId)
```

### VALID RESPONSE CRITERIA

응답에 **반드시 포함**되어야 함:
- ✅ 노드 트리 구조
- ✅ 자식 node-id 목록
- ✅ 노드 이름/타입

### METADATA_FAILURE 분류

응답에 다음이 포함되면 → **METADATA_FAILURE**:
- ❌ 안내문(instruction text)
- ❌ 도구 사용 가이드
- ❌ 빈 내용
- ❌ 구조화되지 않은 일반 문단

---

## 2️⃣ METADATA FAILURE HANDLING

**METADATA_FAILURE 발생 시:**

1. **1회 재시도:**
   - `fileKey` + `node-id` 형식 명시
   
2. **여전히 실패 시:**
   - Metadata 파이프라인 중단
   - **DIRECT_SECTION_MODE**로 전환

---

## 3️⃣ DIRECT_SECTION_MODE

**Metadata 불가 시:**

1. 제공된 root node-id 사용
2. 호출: `get_design_context(rootNodeId)`
3. 응답이 너무 크거나 abort 시:
   - 스크린샷에서 보이는 계층 구조로 재귀 분해
   - 가능하면 자식 node-id 수동 추출 시도
   - 더 작은 노드 범위로 재시도

**`design_context`가 안내문만 반환 → DESIGN_CONTEXT_FAILURE 분류**

---

## 4️⃣ DESIGN_CONTEXT PHASE (Ground Truth 추출)

### 유효한 응답에 반드시 포함:

- ✅ **Layout bounds** (x, y, width, height)
- ✅ **Auto layout config** (direction, gap, align, padding)
- ✅ **Spacing** (간격)
- ✅ **Typography styles** (font, size, weight, line-height, letter-spacing)
- ✅ **Fill/color** (색상)
- ✅ **Component references** (컴포넌트 참조)

### PARTIAL_CONTEXT 분류

위 항목이 **일부만** 누락:
- → **PARTIAL_CONTEXT** 분류
- → 하위 노드 분해 시도

---

## 5️⃣ DESIGN_CONTEXT FAILURE HANDLING

**DESIGN_CONTEXT_FAILURE 발생 시:**

1. 재시도 후에도 실패:
   - `get_screenshot(nodeId)` 호출
   - **INSPECT_MODE**로 전환

2. **INSPECT_MODE:**
   - 스크린샷에서 구조 가정 추출
   - **모든 추론값을 heuristic으로 표시**
   - 출력: `"MCP design_context unavailable — heuristic reconstruction mode"`

---

## 6️⃣ IMPLEMENTATION ORDER

**항상 이 순서로 구현 (결정론적):**

1. Container hierarchy (컨테이너 계층)
2. Layout system (auto layout / flex)
3. Spacing matrix (간격 행렬)
4. Typography system (타이포그래피)
5. Color tokens (색상 토큰)
6. Component instantiation (컴포넌트 인스턴스화)
7. Decorations (장식)

---

## 7️⃣ VALIDATION MODE

**구현 후 (선택):**

1. `get_screenshot(nodeId)` 호출
2. 구조 불일치 감지 시:
   - 해당 노드만 `design_context` 재호출
   - 최소 조정

---

## 8️⃣ STRICT OUTPUT STRUCTURE

**UI 코드 작성 전 반드시 출력:**

### A. Layout Tree
```
- Container (root)
  - Section A (node-id: xxx)
    - Component X
  - Section B (node-id: yyy)
```

### B. Spacing Matrix
```
Section A → Section B: 24px
Section B → Section C: 20px
...
```

### C. Typography Map
```
title: display/6 medium, 24px, 32px line-height
body: display/4 medium, 18px, 24px line-height
...
```

### D. Color Map
```
background: #F8FAFF (Neutral-200)
text-primary: #353E5C (Neutral-700)
primary: #0B66FF (Primary-Blue)
...
```

### E. Component Map
```
AllAgreeBox → Material Container + InkWell
ListRow → Material InkWell + Row
Button → CupertinoButton
...
```

### F. Data Integrity Status

**반드시 다음 중 하나 명시:**

- ✅ **FULL_GROUND_TRUTH**: `get_design_context`에서 모든 스펙 확보
- ⚠️ **PARTIAL_CONTEXT**: 일부 스펙만 확보, 나머지 추론
- 🔧 **HEURISTIC_MODE**: `design_context` 실패, 스크린샷 기반 추론

---

## 🎯 현재 상태 (2025-02-19)

### 실제 MCP 동작:

| 단계 | 도구 | 응답 | 상태 |
|------|------|------|------|
| 1 | `get_metadata(653:4497)` | 안내문만 반환 | ❌ **METADATA_FAILURE** |
| 2 | `get_design_context(653:4497)` | 안내문만 반환 | ❌ **DESIGN_CONTEXT_FAILURE** |
| 3 | `get_screenshot(653:4497)` | 이미지 + 설명 반환 | ✅ 정상 |

### 현재 구현 상태:

- **Data Integrity:** 🔧 **HEURISTIC_MODE**
- **근거:** `get_design_context`가 구조화된 데이터를 반환하지 않아 스크린샷 + 수동 스펙 기반 추론으로 구현
- **표시:** 모든 스펙 값에 `[HEURISTIC]` 마크 권장 (또는 주석으로 명시)

---

## 📋 체크리스트

구현 전:
- [ ] `get_metadata` 호출 → 구조화된 데이터 확인
- [ ] 실패 시 재시도 또는 DIRECT_SECTION_MODE
- [ ] `get_design_context` 호출 → ground truth 확인
- [ ] 실패 시 INSPECT_MODE 전환 및 상태 명시

구현 중:
- [ ] Layout Tree 출력
- [ ] Spacing Matrix 출력
- [ ] Typography Map 출력
- [ ] Color Map 출력
- [ ] Component Map 출력
- [ ] Data Integrity Status 명시

구현 후:
- [ ] (선택) `get_screenshot`으로 diff 체크
- [ ] 구조 불일치 시 해당 노드만 재조정

---

## 🔀 대안: TalkToFigma MCP (Grab)

Figma 공식 Desktop MCP가 metadata/design_context를 반환하지 않을 때, **Grab의 TalkToFigma**를 사용하면 **노드 정보 읽기·Figma 수정**이 가능합니다.

- **방식:** WebSocket 서버 + Figma 플러그인. Cursor ↔ MCP ↔ WebSocket ↔ Figma 플러그인.
- **주요 도구:** `join_channel`, `read_my_design`, `get_node_info`, `get_nodes_info`, `export_node_as_image`, 텍스트/레이아웃/스타일 변경 등.
- **설정·사용:** [docs/FIGMA_TALKTOFIGMA_MCP.md](./FIGMA_TALKTOFIGMA_MCP.md) 참고.
- **프로젝트 MCP 설정:** `.cursor/mcp.json`에 TalkToFigma가 등록되어 있음. WebSocket(`bun socket`) 실행 및 Figma에서 플러그인 채널 접속 후 사용.
