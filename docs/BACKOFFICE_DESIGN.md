# 백오피스 디자인 가이드 (Next.js + Mantine UI)

백오피스 구축 시 Next.js App Router와 Mantine UI를 사용할 때 참고할 레이아웃·인증·디테일 패턴입니다.

---

## 1. 기술 스택

- **프레임워크**: Next.js (App Router)
- **UI**: Mantine v7+ (`@mantine/core`, `@mantine/hooks`)
- **인증**: Supabase Auth + `profiles.role` (admin/council만 접근)

---

## 2. 레이아웃 (Mantine AppShell)

- **구조**: `AppShell` + `AppShell.Header`(상단) + `AppShell.Navbar`(좌측) + `AppShell.Main`(콘텐츠).
- **반응형**: `navbar.collapsed: { mobile: !opened }`, `breakpoint: 'sm'`. 모바일에서는 Burger로 네비바 토글.
- **네비게이션**: `AppShell.Section` + `NavLink`로 메뉴 그룹, 활성 경로는 `active` prop.
- **상단**: 로고/타이틀, 로그인 사용자(이름·역할), 로그아웃 버튼(예: `NavLink` c="red").

```tsx
// 참고: AppShell + NavLink 패턴
<AppShell
  header={{ height: 60 }}
  navbar={{ width: 280, breakpoint: 'sm', collapsed: { mobile: !opened } }}
  padding="md"
>
  <AppShell.Header>
    <Group h="100%" px="md" justify="space-between">
      <Burger opened={opened} onClick={toggle} hiddenFrom="sm" size="sm" />
      <Text fw={700} size="lg">LAON 백오피스</Text>
      <Group><Text>{userName}</Text><Text c="dimmed">{role}</Text><Button variant="subtle" c="red">로그아웃</Button></Group>
    </Group>
  </AppShell.Header>
  <AppShell.Navbar p="md">
    <AppShell.Section grow component={ScrollArea}>
      {navItems.map((item) => (
        <NavLink key={item.href} active={pathname === item.href} label={item.label} leftSection={<item.icon size={16} />} href={item.href} />
      ))}
    </AppShell.Section>
  </AppShell.Navbar>
  <AppShell.Main>{children}</AppShell.Main>
</AppShell>
```

---

## 3. 인증·역할 검사 (Next.js)

- **미인증**: 401, 로그인 페이지로 리다이렉트.
- **역할 부족(admin/council 아님)**: 403, "권한 없음" 페이지 또는 로그인으로.

```ts
// Route Handler / Server Component 예시
const session = await getSession(); // Supabase 등
if (!session) return new Response(null, { status: 401 });
const profile = await getProfile(session.user.id);
if (profile?.role !== 'admin' && profile?.role !== 'council')
  return new Response(null, { status: 403 });
```

- **레이아웃**: `(dashboard)/layout.tsx`에서 세션·역할 검사 후 위 AppShell로 감싸기.

---

## 4. 색상·디자인

- **LAON 브랜드 유지**: Primary 블루(`#0B66FF`), 화이트 배경, 삭제 등 위험 작업은 빨간 계열.
- **Mantine 테마**: `MantineProvider`에서 `primaryColor`를 blue로, `colors` 오버라이드로 브랜드 블루 지정.
- **테이블**: Mantine `Table` + 스트라이프 또는 호버, 정렬 헤더, 페이지네이션(`Pagination`).
- **폼**: `TextInput`, `Select`, `DateTimePicker` 등 + 유효성(필수, 형식).

---

## 5. 디테일 체크리스트

- [ ] 모든 백오피스 라우트에 인증 + admin/council 검사 적용
- [ ] AppShell 네비바에 대시보드, 프로필, 일정, 건의함, 공지, 투표, 버그신고, 채팅방, 과목/과제 등 메뉴 매핑
- [ ] 목록 페이지: 필터·정렬·페이지네이션, 삭제 시 확인 모달
- [ ] 폼: 제출 전 클라이언트 유효성, 에러 메시지 인라인 표시
- [ ] 로딩: Skeleton 또는 Loader, 에러 시 Alert + 재시도
- [ ] 반응형: navbar 280px(데스크톱), 모바일에서 Burger로 접기
