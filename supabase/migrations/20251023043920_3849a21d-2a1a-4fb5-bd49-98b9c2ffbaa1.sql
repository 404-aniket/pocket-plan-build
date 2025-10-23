-- Create profiles table for user information
CREATE TABLE public.profiles (
  id UUID NOT NULL REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT,
  phone TEXT,
  date_of_birth DATE,
  medical_conditions TEXT[],
  allergies TEXT[],
  profile_picture_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create emergency contacts table
CREATE TABLE public.emergency_contacts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  relationship TEXT,
  phone TEXT NOT NULL,
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create medication trays table
CREATE TABLE public.medication_trays (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tray_number INTEGER NOT NULL CHECK (tray_number BETWEEN 1 AND 10),
  medicine_name TEXT NOT NULL,
  morning_quantity INTEGER DEFAULT 0,
  morning_time TIME,
  afternoon_quantity INTEGER DEFAULT 0,
  afternoon_time TIME,
  evening_quantity INTEGER DEFAULT 0,
  evening_time TIME,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, tray_number)
);

-- Create schedules table for 30-day schedule generation
CREATE TABLE public.schedules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  schedule_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create adherence tracking table
CREATE TABLE public.adherence_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  medication_tray_id UUID NOT NULL REFERENCES public.medication_trays(id) ON DELETE CASCADE,
  scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
  taken_time TIMESTAMP WITH TIME ZONE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'taken', 'missed', 'skipped')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create reminder settings table
CREATE TABLE public.reminder_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  notification_enabled BOOLEAN DEFAULT true,
  snooze_duration_minutes INTEGER DEFAULT 10,
  advance_reminder_minutes INTEGER DEFAULT 15,
  notification_sound TEXT DEFAULT 'default',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medication_trays ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adherence_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reminder_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- RLS Policies for emergency_contacts
CREATE POLICY "Users can view own emergency contacts"
  ON public.emergency_contacts FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own emergency contacts"
  ON public.emergency_contacts FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own emergency contacts"
  ON public.emergency_contacts FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own emergency contacts"
  ON public.emergency_contacts FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for medication_trays
CREATE POLICY "Users can view own medication trays"
  ON public.medication_trays FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own medication trays"
  ON public.medication_trays FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own medication trays"
  ON public.medication_trays FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own medication trays"
  ON public.medication_trays FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for schedules
CREATE POLICY "Users can view own schedules"
  ON public.schedules FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own schedules"
  ON public.schedules FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own schedules"
  ON public.schedules FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own schedules"
  ON public.schedules FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for adherence_logs
CREATE POLICY "Users can view own adherence logs"
  ON public.adherence_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own adherence logs"
  ON public.adherence_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own adherence logs"
  ON public.adherence_logs FOR UPDATE
  USING (auth.uid() = user_id);

-- RLS Policies for reminder_settings
CREATE POLICY "Users can view own reminder settings"
  ON public.reminder_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own reminder settings"
  ON public.reminder_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reminder settings"
  ON public.reminder_settings FOR UPDATE
  USING (auth.uid() = user_id);

-- Create function to handle profile creation on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'full_name', '')
  );
  
  -- Create default reminder settings
  INSERT INTO public.reminder_settings (user_id)
  VALUES (new.id);
  
  RETURN new;
END;
$$;

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_medication_trays_updated_at
  BEFORE UPDATE ON public.medication_trays
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_reminder_settings_updated_at
  BEFORE UPDATE ON public.reminder_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();