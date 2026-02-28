-- RLS 없이 댓글 목록 + 작성자(이름·아바타) 한 번에 조회. anon/일반 학생 환경에서도 프로필 사진 표시 보장.

CREATE OR REPLACE FUNCTION public.get_poll_comments_with_authors(p_poll_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'poll_id', c.poll_id,
        'author_id', c.author_id,
        'content', c.content,
        'created_at', c.created_at,
        'author_name', coalesce(p.full_name, ''),
        'author_avatar_url', coalesce(
          nullif(trim(p.avatar_url), ''),
          'https://api.dicebear.com/9.x/notionists/png?seed=' || c.author_id::text
        )
      )
      ORDER BY c.created_at ASC
    ),
    '[]'::jsonb
  ) INTO v_result
  FROM public.poll_comments c
  LEFT JOIN public.profiles p ON p.id = c.author_id
  WHERE c.poll_id = p_poll_id;

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.get_poll_comments_with_authors(uuid) IS
  '투표 댓글 목록 + 작성자 이름·프로필 사진. RLS 우회로 앱에서 항상 표시.';

GRANT EXECUTE ON FUNCTION public.get_poll_comments_with_authors(uuid) TO anon, authenticated;
