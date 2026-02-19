## 1. 브랜치 전략 – Trunk-based Development

### 1.1 기본 원칙

- `main` 브랜치는 **항상 배포 가능한 상태**
- `main` = 현재 라이브에 배포된 버전
- 모든 작업은 **main에서 분기한 짧은 생명의 feature 브랜치**에서 수행

공식 개념 참고:

https://trunkbaseddevelopment.com/

### 1.2 브랜치 규칙

- `main` 직접 커밋 ❌
- 모든 변경 사항은 PR을 통해서만 `main`에 병합
- PR 크기 권장: **300~400줄 이내**

### 브랜치 네이밍 규칙

```
feature/<작업명>
fix/<버그명>
refactor/<대상>
hotfix/<이슈명>

```

예시:

```
feature/login-ui
fix/auth-token-error
refactor/api-layer

```

---

## 2. Git 협업 명령어 표준 흐름

### 2.1 최초 세팅 (처음 한 번)

```bash
git clone <repo-url>
cd <repo-name>
git checkout -b feature/<작업명>

```

- 원격 레포 복제
- 개인 작업 브랜치 생성

---

### 2.2 작업 시작 전 (매번 필수)

```bash
git checkout main
git pull origin main
git checkout feature/<작업명>
git merge main
```

- 최신 main 반영
- 충돌은 **작업 시작 전에 해결**

---

### 3.3 작업 중 기본 루틴

```bash
git status
git add .
git commit -m "feat(api): 로그인 API 추가"

```

- 작은 단위 커밋 권장
- 의미 없는 커밋 메시지 금지

---

### 3.4 원격 브랜치 푸시

```bash
git push origin feature/<작업명>

```

- PR 생성 준비 단계

---

### 3.5 코드 리뷰 반영

```bash
git add .
git commit -m "fix(api): 리뷰 반영 – 에러 처리 수정"
git push origin feature/<작업명>

```

---

### 3.6 PR 머지 후 정리

```bash
git checkout main
git pull origin main
git branch -d feature/<작업명>

```

- 로컬 브랜치 정리
- 원격 브랜치는 GitHub/GitLab에서 삭제

---

### 3.7 충돌 발생 시

```bash
git status
# 충돌 파일 수정
git add .
git commit

```

---

## 4. Conventional Commits 규칙

GOODWILL 레포지토리는 **Conventional Commits** 규칙을 따른다.

모든 커밋은 **수정 종류 + 영향 범위 + 요약**을 명확히 드러내야 한다.

공식 문서:

https://www.conventionalcommits.org/en/v1.0.0/

### 4.1 커밋 메시지 형식

```
<타입>(<영향_범위>): <수정사항_한줄_요약>

```

```
feat(transfer): 송금 요청 API 추가
fix(my-insurance): 보험료 계산 오류 수정
refactor(business-ledger): 회계 로직 구조 개선

```

### 4.2 커밋 타입 목록

- `feat` : 새로운 기능 → 기존에 있는 페이지에 새로운 기능을 추가하거나 개선했으면 feature.
- `fix` : 버그 수정 → 만약 어떤 버튼이 있는데, 눌리지 않아서 오류를 해결했으면 이에 해당함.
- `perf` : 성능 개선
- `refactor` : 리팩토링 (기능 변경 없음)
- `test` : 테스트 코드
- `ci` : CI/CD 설정
- `docs` : 문서 수정
- `build` : 빌드 시스템
- `chore` : 기타 작업

### 4.3 영향 범위(scope)

### 4.3.1 UI / 화면 계층

```
ui        : 공통 UI / 컴포넌트
layout    : 페이지 구조
main      : 메인 페이지
landing   : 랜딩 페이지

```

### 4.3.2 기능/도메인

```
auth      : 인증/인가
account   : 계정
content   : 게시물/공지
search    : 검색

```

### 4.3.3 기술 관심사

```
seo       : SEO / 메타
perf      : 성능 최적화
infra     : 인프라 설정

```

---

### 4.3.4 실제 사용 예시

```bash
feat(main): remove hero section buttons
fix(auth): resolve login redirect issue
perf(ui): reduce bundle size
docs(content): update announcement guide

```

---

### 4.3.5 운영 규칙 (중요)

- scope는 **선택 사항**
- 헷갈리면 **생략해도 된다**
- 새로운 scope 추가는 **합의 후**

> ❌ feat(header-hero-main-ui)
> 
> 
> ❌ `feat(ui-button-remove)`
> 
> → 이런 건 과하다
> 

---

---

## 5. 금지 사항 (중요)

다음 행위는 **절대 금지**한다.

```bash
git push origin main
git commit -m "수정"
git pull 없이 작업 시작

```

---

---