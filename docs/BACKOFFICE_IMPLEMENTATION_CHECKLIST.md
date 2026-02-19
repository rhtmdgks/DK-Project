# 백오피스 구현 체크리스트

## 현재 상태 분석

백오피스 프로젝트(`/Users/s.h.putrats/Documents/GitHub/DK-Project_Backoffice`)는 Next.js 기반으로 구축되어 있으며, 기본적인 페이지 구조는 이미 존재합니다.

## 구현 필요 기능 목록

### ✅ 이미 구현된 기능 (확인 필요)

1. **건의함 (Suggestions)**
   - 목록 조회: ✅ 구현됨 (`components/suggestions/suggestions-content.tsx`)
   - 상태 변경: ⚠️ 확인 필요 (status 업데이트 로직 확인)

2. **채팅방 관리 (Chat Rooms)**
   - 방 목록 조회: ✅ 구현됨 (`components/chat-rooms/chat-rooms-content.tsx`)
   - 방 생성: ⚠️ 확인 필요
   - 멤버 관리: ⚠️ 확인 필요

3. **프로필 관리 (Profiles)**
   - 목록 조회: ✅ 페이지 존재 (`app/profiles/page.tsx`)
   - CRUD 기능: ⚠️ 확인 필요

4. **공지사항 (Announcements)**
   - 목록 조회: ✅ 페이지 존재 (`app/announcements/page.tsx`)
   - CRUD 기능: ⚠️ 확인 필요

### ❌ 구현 필요 기능

#### 1. 건의함 (Suggestions) - 상태 변경 기능

**현재 상태:**
- 메인 프로젝트의 `suggestions` 테이블은 `status`가 `'pending' | 'approved' | 'rejected'`로 정의됨
- 백오피스 스펙에서는 `pending → reviewed → resolved`로 명시되어 있으나, 실제 DB는 `pending/approved/rejected` 사용

**구현 필요:**
- [ ] 건의사항 상태 변경 기능 (`pending` → `approved` 또는 `rejected`)
- [ ] 상태 변경 시 RPC 함수 사용 또는 직접 UPDATE (RLS 정책 확인 필요)
- [ ] 상태 변경 히스토리 로깅 (선택사항)

**RLS 정책 확인:**
```sql
-- 현재 정책: Authors can update own suggestions
-- Council/admin도 status를 변경할 수 있도록 RPC 함수 필요할 수 있음
```

**권장 구현:**
```typescript
// RPC 함수 생성 필요
CREATE OR REPLACE FUNCTION public.update_suggestion_status(
  p_suggestion_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- 권한 확인 (council/admin만)
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE user_id = auth.uid() AND role IN ('council', 'admin')
  ) THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;
  
  -- 상태 업데이트
  UPDATE public.suggestions
  SET status = p_status, updated_at = now()
  WHERE id = p_suggestion_id;
  
  RETURN jsonb_build_object('success', true);
END;
$$;
```

#### 2. 공지사항 (Announcements) - CRUD 기능

**구현 필요:**
- [ ] 공지사항 생성 기능
- [ ] 공지사항 수정 기능
- [ ] 공지사항 삭제 기능
- [ ] 작성자 정보 표시 (profiles 연동)

**RLS 정책:**
- Council/admin만 INSERT 가능
- 작성자만 UPDATE 가능

**구현 위치:** `components/announcements/announcements-content.tsx`

#### 3. 투표 (Polls) - CRUD 기능

**구현 필요:**
- [ ] 투표 목록 조회 (이미 페이지 존재)
- [ ] 투표 생성 기능 (question, options jsonb)
- [ ] 투표 삭제 기능
- [ ] 투표 현황 조회 (poll_votes 집계)

**특별 고려사항:**
- `options`는 JSONB 배열 형식
- `ends_at` (종료 시각) 설정
- `announcement_id` 연결 (선택사항)

**구현 위치:** `components/polls/polls-content.tsx` (생성 필요)

#### 4. 일정 관리 (Schedule Items) - CRUD 기능

**구현 필요:**
- [ ] 일정 목록 조회
- [ ] 일정 추가 (title, description, start_at, end_at)
- [ ] 일정 수정
- [ ] 일정 삭제

**제약사항:**
- `end_at > start_at` 체크 필요
- `created_by`는 현재 로그인한 admin/council의 profile id

**구현 위치:** `app/calendar/page.tsx` 또는 새 페이지 생성

#### 5. 채팅방 관리 - 완전한 구현

**현재 상태 확인 필요:**
- [ ] 그룹 채팅방 생성 기능 (`type = 'group'`)
- [ ] 채팅방 멤버 추가 기능
- [ ] 채팅방 멤버 제거 기능
- [ ] 채팅방 삭제 기능

**특별 고려사항:**
- 1:1 채팅방은 앱에서 자동 생성되므로 백오피스에서는 그룹 채팅방만 관리
- `chat_room_members` INSERT는 admin/council만 가능 (RLS 정책)

#### 6. 프로필 관리 - 완전한 구현

**구현 필요:**
- [ ] 프로필 목록 조회 (role 필터링, student_id 검색)
- [ ] 프로필 상세 조회
- [ ] 역할 변경 (role: student/council/admin)
- [ ] 기타 필드 수정 (full_name 등)

**주의사항:**
- 본인 role 강등 시 재로그인 필요
- 비밀번호 변경은 별도 플로우 (앱에서 처리)

#### 7. 버그 신고 (Bug Reports) - CRUD 기능

**구현 필요:**
- [ ] 버그 신고 목록 조회
- [ ] 버그 신고 상세 조회 (이미지 표시)
- [ ] 상태 변경 (pending → in_progress → resolved → closed)

**특별 고려사항:**
- `image_urls`는 Storage의 `bug-reports` 버킷에서 가져오기
- `location` 정보 표시

**구현 위치:** `components/bug-reports/bug-reports-content.tsx` (생성 필요)

#### 8. 과목·분반 관리 (Subjects & Subject Divisions)

**구현 필요:**
- [ ] 과목 목록 조회
- [ ] 과목 추가/수정/삭제 (admin만)
- [ ] 분반 목록 조회 (과목별)
- [ ] 분반 추가/수정/삭제 (admin만)

**RLS 정책:**
- 과목/분반 관리는 admin만 가능

**구현 위치:** `app/timetables/page.tsx` 또는 새 페이지

#### 9. 과제 관리 (Assignments)

**구현 필요:**
- [ ] 과제 목록 조회 (분반별 필터)
- [ ] 과제 추가
- [ ] 과제 수정
- [ ] 과제 삭제

**필드:**
- `division_id`, `title`, `description`, `due_at`, `attachment_url`, `created_by`

**구현 위치:** 새 페이지 생성 필요

#### 10. 수강 신청 관리 (Student Enrollments)

**구현 필요:**
- [ ] 수강 목록 조회 (프로필별/분반별 필터)
- [ ] 수강 등록 (profile_id + division_id)
- [ ] 수강 취소

**구현 위치:** 새 페이지 생성 필요

#### 11. 시간표 관리 (Timetable Entries) - 선택사항

**구현 필요:**
- [ ] 사용자별 시간표 조회
- [ ] 시간표 수정 (admin/council만)

**구현 위치:** `app/timetables/page.tsx`에 통합 가능

### 🔧 시스템 기능 개선 필요

#### 1. 인증 및 권한 검사

**구현 필요:**
- [ ] 모든 페이지에서 role 검사 미들웨어/컴포넌트
- [ ] admin/council이 아니면 접근 거부
- [ ] 세션 만료 처리

**구현 방법:**
```typescript
// middleware.ts 또는 각 페이지에서
const { data: profile } = await supabase
  .from('profiles')
  .select('role')
  .eq('user_id', user.id)
  .single()

if (profile?.role !== 'admin' && profile?.role !== 'council') {
  redirect('/login')
}
```

#### 2. 대시보드 (Dashboard)

**구현 필요:**
- [ ] 오늘 일정 수 표시
- [ ] 미처리 건의 수 표시 (status = 'pending')
- [ ] 최근 7일 버그 신고 수 표시
- [ ] 각 항목별 관리 페이지 링크

**구현 위치:** `app/page.tsx`

#### 3. RPC 함수 생성

**필요한 RPC 함수들:**

1. **건의함 상태 변경**
```sql
CREATE OR REPLACE FUNCTION public.update_suggestion_status(
  p_suggestion_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 권한 확인
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE user_id = auth.uid() AND role IN ('council', 'admin')
  ) THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;
  
  UPDATE public.suggestions
  SET status = p_status, updated_at = now()
  WHERE id = p_suggestion_id;
  
  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_suggestion_status(uuid, text) TO authenticated;
```

2. **버그 신고 상태 변경**
```sql
CREATE OR REPLACE FUNCTION public.update_bug_report_status(
  p_bug_report_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 권한 확인
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE user_id = auth.uid() AND role IN ('council', 'admin')
  ) THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;
  
  UPDATE public.bug_reports
  SET status = p_status, updated_at = now()
  WHERE id = p_bug_report_id;
  
  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_bug_report_status(uuid, text) TO authenticated;
```

3. **프로필 역할 변경**
```sql
CREATE OR REPLACE FUNCTION public.update_profile_role(
  p_profile_id uuid,
  p_new_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 권한 확인 (admin만)
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'insufficient_privilege';
  END IF;
  
  -- 역할 검증
  IF p_new_role NOT IN ('student', 'council', 'admin') THEN
    RAISE EXCEPTION 'invalid_role';
  END IF;
  
  UPDATE public.profiles
  SET role = p_new_role, updated_at = now()
  WHERE id = p_profile_id;
  
  RETURN jsonb_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_profile_role(uuid, text) TO authenticated;
```

## 우선순위별 구현 계획

### Phase 1: 핵심 관리 기능 (최우선)
1. ✅ 건의함 상태 변경 기능 완성
2. ✅ 공지사항 CRUD 완성
3. ✅ 투표 CRUD 완성
4. ✅ 일정 관리 CRUD 완성
5. ✅ 대시보드 구현

### Phase 2: 사용자 및 채팅 관리
1. ✅ 프로필 관리 완성
2. ✅ 채팅방 관리 완성 (그룹 채팅방)
3. ✅ 버그 신고 관리 완성

### Phase 3: 학사 관리 기능
1. ✅ 과목/분반 관리
2. ✅ 과제 관리
3. ✅ 수강 신청 관리
4. ✅ 시간표 관리 (선택)

## 기술적 고려사항

### 1. RLS 정책과의 통합

백오피스는 `authenticated` 역할로 접근하지만, 실제 권한은 `profiles.role`로 확인해야 합니다.

**권장 접근 방법:**
- RPC 함수를 사용하여 권한 검사와 작업 수행
- 또는 백오피스 전용 서비스 역할 키 사용 (보안상 주의)

### 2. 실시간 업데이트

채팅방, 건의함 등은 실시간 업데이트가 필요할 수 있습니다.

**구현 방법:**
- Supabase Realtime 구독
- 또는 폴링 방식

### 3. 이미지 처리

버그 신고의 `image_urls`는 Supabase Storage에서 관리됩니다.

**구현 필요:**
- Storage 버킷 접근 권한 확인
- 이미지 미리보기 기능

## 체크리스트 요약

### 즉시 구현 필요 (Phase 1)
- [ ] 건의함 상태 변경 기능 완성
- [ ] 공지사항 CRUD 완성
- [ ] 투표 CRUD 완성
- [ ] 일정 관리 CRUD 완성
- [ ] 대시보드 구현
- [ ] RPC 함수들 생성 및 배포

### 다음 단계 (Phase 2)
- [ ] 프로필 관리 완성
- [ ] 채팅방 관리 완성
- [ ] 버그 신고 관리 완성

### 추가 기능 (Phase 3)
- [ ] 과목/분반 관리
- [ ] 과제 관리
- [ ] 수강 신청 관리
