# 시간표 데이터 유실 점검/복구 가이드

## 1) 원인 후보
- 파괴적 정리 SQL/스크립트 실행으로 `timetable_entries` 삭제
- `auth.users` 삭제로 인한 FK `ON DELETE CASCADE` 연쇄 삭제
- 백오피스 동기화 시 `user_id` 매핑 오류(`profiles.id` 사용 등)

## 2) 진단 순서
1. Supabase SQL Editor에서 `supabase/recovery/timetable_diagnostics_and_sync.sql`의 **진단 쿼리**만 먼저 실행
2. `timetable_entries_count`, 사용자별 분포, `profiles.user_id` 정합성 확인
3. `class_timetable_change_logs` 최근 기록으로 변경 시점 확인

## 3) 복구/동기화
- `class_timetable` 기준으로 학생별 `timetable_entries`를 재생성/업데이트하려면
  같은 SQL 파일의 **복구/동기화 쿼리**를 실행
- 쿼리는 `ON CONFLICT (user_id, day_of_week, period)` 업서트이므로 반복 실행 가능

## 4) 사후 검증
- 같은 SQL 파일의 **사후 검증**으로 건수/슬롯 분포를 확인
- 앱에서 월~금 요일 탭을 열어 표본 학생 2~3명의 시간표가 정상 노출되는지 점검

## 5) 운영 안전장치
- 백오피스 파괴 스크립트 `scripts/purge-schedule-data.mjs`는
  `CONFIRM_PURGE=PURGE_SCHEDULE_TIMETABLE_DATA` 없이는 실행되지 않도록 가드가 적용됨
- `DRY_RUN=1`로 실제 삭제 전에 영향 건수를 먼저 확인 가능
