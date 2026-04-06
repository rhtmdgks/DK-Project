-- Harden chat RPCs: remove anon execute and bind identity to auth.uid().

create or replace function public.get_chat_messages(
  p_room_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_ok boolean;
  v_result jsonb;
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null or v_uid <> p_user_id then
    raise exception 'unauthorized' using errcode = 'P0001';
  end if;

  select exists (
    select 1 from public.chat_room_members
    where room_id = p_room_id and user_id = v_uid
  ) into v_member_ok;

  if not v_member_ok then
    return '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', m.id,
        'room_id', m.room_id,
        'sender_id', m.sender_id,
        'content', m.content,
        'created_at', m.created_at,
        'attachment_url', m.attachment_url,
        'attachment_type', m.attachment_type,
        'sender_full_name', p.full_name,
        'sender_student_id', p.student_id,
        'sender_avatar_url', p.avatar_url
      )
      order by m.created_at asc
    ),
    '[]'::jsonb
  ) into v_result
  from public.chat_messages m
  left join public.profiles p on p.user_id = m.sender_id
  where m.room_id = p_room_id;

  return v_result;
end;
$$;

create or replace function public.insert_chat_message(
  p_room_id uuid,
  p_sender_id uuid,
  p_content text,
  p_attachment_url text default null,
  p_attachment_type text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_ok boolean;
  v_new_id uuid;
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null or v_uid <> p_sender_id then
    raise exception 'unauthorized' using errcode = 'P0001';
  end if;

  select exists (
    select 1 from public.chat_room_members
    where room_id = p_room_id and user_id = v_uid
  ) into v_member_ok;

  if not v_member_ok then
    raise exception 'not_room_member' using errcode = 'P0001';
  end if;

  insert into public.chat_messages (
    room_id, sender_id, content, attachment_url, attachment_type
  )
  values (
    p_room_id,
    v_uid,
    coalesce(trim(p_content), ''),
    nullif(trim(p_attachment_url), ''),
    nullif(trim(p_attachment_type), '')
  )
  returning id into v_new_id;

  return v_new_id;
end;
$$;

revoke execute on function public.get_chat_messages(uuid, uuid) from anon;
revoke execute on function public.insert_chat_message(uuid, uuid, text, text, text) from anon;
grant execute on function public.get_chat_messages(uuid, uuid) to authenticated;
grant execute on function public.insert_chat_message(uuid, uuid, text, text, text) to authenticated;
