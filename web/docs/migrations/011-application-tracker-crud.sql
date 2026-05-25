-- Migration: Application tracker CRUD support

ALTER TABLE public.application_tracker
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id),
  ADD COLUMN IF NOT EXISTS school_name TEXT,
  ADD COLUMN IF NOT EXISTS program_name TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_application_tracker_user_id
  ON public.application_tracker(user_id);

CREATE INDEX IF NOT EXISTS idx_application_tracker_program_id
  ON public.application_tracker(program_id);

CREATE INDEX IF NOT EXISTS idx_application_tracker_school_id
  ON public.application_tracker(school_id);

CREATE INDEX IF NOT EXISTS idx_application_tracker_status
  ON public.application_tracker(status);

CREATE INDEX IF NOT EXISTS idx_application_tracker_deadline
  ON public.application_tracker(deadline);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_application_tracker_updated_at
  ON public.application_tracker;

CREATE TRIGGER update_application_tracker_updated_at
  BEFORE UPDATE ON public.application_tracker
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.application_tracker ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own tracker"
  ON public.application_tracker;
DROP POLICY IF EXISTS "Users can insert own tracker"
  ON public.application_tracker;
DROP POLICY IF EXISTS "Users can update own tracker"
  ON public.application_tracker;
DROP POLICY IF EXISTS "Users can delete own tracker"
  ON public.application_tracker;

CREATE POLICY "Users can view own tracker"
  ON public.application_tracker
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own tracker"
  ON public.application_tracker
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own tracker"
  ON public.application_tracker
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own tracker"
  ON public.application_tracker
  FOR DELETE
  USING (auth.uid() = user_id);
