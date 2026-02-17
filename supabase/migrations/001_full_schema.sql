-- School Official App — Full Schema
-- RLS enabled on ALL tables. All constraints and indexes explicit.

-- Enable required extensions (if not already)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- PROFILES (extends auth.users)
-- =============================================================================
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  student_id text NOT NULL,
  role text NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'council', 'admin')),
  must_change_password boolean NOT NULL DEFAULT true,
  full_name text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id),
  UNIQUE(student_id)
);

CREATE INDEX idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX idx_profiles_student_id ON public.profiles(student_id);
CREATE INDEX idx_profiles_role ON public.profiles(role);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own profile (e.g. must_change_password)"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Only service role inserts profiles (seed). No INSERT policy for anon/authenticated.

-- =============================================================================
-- SUGGESTIONS
-- =============================================================================
CREATE TABLE public.suggestions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_suggestions_author_id ON public.suggestions(author_id);
CREATE INDEX idx_suggestions_status ON public.suggestions(status);
CREATE INDEX idx_suggestions_created_at ON public.suggestions(created_at DESC);

ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own suggestions"
  ON public.suggestions FOR SELECT
  USING (
    author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
    OR
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

CREATE POLICY "Users can insert own suggestions"
  ON public.suggestions FOR INSERT
  WITH CHECK (
    author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid())
  );

CREATE POLICY "Authors can update own suggestions"
  ON public.suggestions FOR UPDATE
  USING (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
  WITH CHECK (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- Council/admin can update status; same policy allows update for author (body/title). For status-only, use RPC if needed.

-- =============================================================================
-- CHAT ROOMS & MEMBERS
-- =============================================================================
CREATE TABLE public.chat_rooms (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.chat_room_members (
  room_id uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (room_id, user_id),
  UNIQUE(room_id, user_id)
);

CREATE INDEX idx_chat_room_members_user_id ON public.chat_room_members(user_id);
CREATE INDEX idx_chat_room_members_room_id ON public.chat_room_members(room_id);

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_room_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read rooms they belong to"
  ON public.chat_rooms FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.chat_room_members WHERE chat_room_members.room_id = chat_rooms.id AND chat_room_members.user_id = auth.uid())
  );

CREATE POLICY "Members can read room membership"
  ON public.chat_room_members FOR SELECT
  USING (
    room_id IN (SELECT room_id FROM public.chat_room_members crm WHERE crm.user_id = auth.uid())
  );

CREATE POLICY "Admin/council can insert room members"
  ON public.chat_room_members FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

-- =============================================================================
-- CHAT MESSAGES
-- =============================================================================
CREATE TABLE public.chat_messages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id uuid NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_chat_messages_room_id ON public.chat_messages(room_id);
CREATE INDEX idx_chat_messages_room_created ON public.chat_messages(room_id, created_at DESC);
CREATE INDEX idx_chat_messages_sender_id ON public.chat_messages(sender_id);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Room members can read messages"
  ON public.chat_messages FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.chat_room_members WHERE room_id = chat_messages.room_id AND user_id = auth.uid())
  );

CREATE POLICY "Room members can insert messages"
  ON public.chat_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (SELECT 1 FROM public.chat_room_members WHERE room_id = chat_messages.room_id AND user_id = auth.uid())
  );

-- =============================================================================
-- ANNOUNCEMENTS
-- =============================================================================
CREATE TABLE public.announcements (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_announcements_author_id ON public.announcements(author_id);
CREATE INDEX idx_announcements_created_at ON public.announcements(created_at DESC);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read announcements"
  ON public.announcements FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Council/admin can insert announcements"
  ON public.announcements FOR INSERT
  WITH CHECK (
    author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

CREATE POLICY "Authors can update own announcements"
  ON public.announcements FOR UPDATE
  USING (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()))
  WITH CHECK (author_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid()));

-- =============================================================================
-- POLLS
-- =============================================================================
CREATE TABLE public.polls (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  announcement_id uuid REFERENCES public.announcements(id) ON DELETE SET NULL,
  question text NOT NULL,
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_polls_announcement_id ON public.polls(announcement_id);
CREATE INDEX idx_polls_ends_at ON public.polls(ends_at);
CREATE INDEX idx_polls_created_at ON public.polls(created_at DESC);

ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read polls"
  ON public.polls FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Council/admin can manage polls"
  ON public.polls FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

-- =============================================================================
-- POLL VOTES (1 vote per user per poll — DB constraint)
-- =============================================================================
CREATE TABLE public.poll_votes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  option_index int NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(poll_id, user_id)
);

CREATE INDEX idx_poll_votes_poll_id ON public.poll_votes(poll_id);
CREATE INDEX idx_poll_votes_user_id ON public.poll_votes(user_id);

ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read all votes (for counts)"
  ON public.poll_votes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can insert own vote only once (enforced by UNIQUE)"
  ON public.poll_votes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- No UPDATE/DELETE on votes (immutable).

-- =============================================================================
-- SCHEDULE ITEMS (school-wide or class events)
-- =============================================================================
CREATE TABLE public.schedule_items (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  description text,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT schedule_items_valid_range CHECK (end_at > start_at)
);

CREATE INDEX idx_schedule_items_start_at ON public.schedule_items(start_at);
CREATE INDEX idx_schedule_items_end_at ON public.schedule_items(end_at);
CREATE INDEX idx_schedule_items_created_by ON public.schedule_items(created_by);

ALTER TABLE public.schedule_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read schedule items"
  ON public.schedule_items FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Council/admin can insert schedule items"
  ON public.schedule_items FOR INSERT
  WITH CHECK (
    created_by IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
    OR created_by IS NULL
  );

CREATE POLICY "Council/admin can update schedule items"
  ON public.schedule_items FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

CREATE POLICY "Council/admin can delete schedule items"
  ON public.schedule_items FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

-- =============================================================================
-- TIMETABLE ENTRIES (per-user weekly timetable; no overlap per day/period)
-- =============================================================================
CREATE TABLE public.timetable_entries (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  day_of_week smallint NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6),
  period smallint NOT NULL CHECK (period >= 1 AND period <= 20),
  subject text NOT NULL,
  room text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, day_of_week, period)
);

CREATE INDEX idx_timetable_entries_user_id ON public.timetable_entries(user_id);
CREATE INDEX idx_timetable_entries_user_day ON public.timetable_entries(user_id, day_of_week);

ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own timetable"
  ON public.timetable_entries FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM public.profiles WHERE user_id = auth.uid() AND role IN ('council', 'admin'))
  );

CREATE POLICY "Users can insert own timetable"
  ON public.timetable_entries FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own timetable"
  ON public.timetable_entries FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own timetable"
  ON public.timetable_entries FOR DELETE
  USING (auth.uid() = user_id);

-- =============================================================================
-- RPC: Update must_change_password (called after password change from client)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.set_must_change_password_false()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET must_change_password = false, updated_at = now()
  WHERE user_id = auth.uid();
END;
$$;

-- Allow authenticated to call (only updates own row via auth.uid())
GRANT EXECUTE ON FUNCTION public.set_must_change_password_false() TO authenticated;

-- =============================================================================
-- Trigger: updated_at for profiles
-- =============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER suggestions_updated_at
  BEFORE UPDATE ON public.suggestions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
