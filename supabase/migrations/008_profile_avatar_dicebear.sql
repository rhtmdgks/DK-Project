-- =============================================================================
-- 프로필 아바타: 계정(프로필) 생성/갱신 시 DiceBear URL 자동 설정
-- =============================================================================
-- profiles 행이 INSERT되거나, avatar_url이 비어 있을 때
-- DiceBear notionists 스타일 URL을 자동으로 넣습니다.
-- seed = user_id 로 동일 사용자는 항상 같은 아바타가 나옵니다.

-- 1) avatar_url 컬럼이 없으면 추가
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_url text;

-- 2) 트리거 함수: avatar_url이 비어 있으면 DiceBear URL 설정
CREATE OR REPLACE FUNCTION public.set_profile_avatar_dicebear()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.avatar_url IS NULL OR trim(NEW.avatar_url) = '' THEN
    NEW.avatar_url := 'https://api.dicebear.com/9.x/notionists/svg?seed=' || NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$;

-- 3) INSERT 시 자동 설정
DROP TRIGGER IF EXISTS profiles_set_avatar_on_insert ON public.profiles;
CREATE TRIGGER profiles_set_avatar_on_insert
  BEFORE INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_profile_avatar_dicebear();

-- 4) UPDATE 시에도 avatar_url이 비어 있으면 설정
DROP TRIGGER IF EXISTS profiles_set_avatar_on_update ON public.profiles;
CREATE TRIGGER profiles_set_avatar_on_update
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  WHEN (OLD.avatar_url IS DISTINCT FROM NEW.avatar_url AND (NEW.avatar_url IS NULL OR trim(NEW.avatar_url) = ''))
  EXECUTE FUNCTION public.set_profile_avatar_dicebear();

-- 5) 기존 프로필 중 avatar_url이 비어 있는 행 일괄 업데이트
UPDATE public.profiles
SET avatar_url = 'https://api.dicebear.com/9.x/notionists/svg?seed=' || user_id
WHERE avatar_url IS NULL OR trim(avatar_url) = '';
