/*
  # Initial Schema Setup for SponsorSync

  1. New Tables
    - `profiles`
      - `id` (uuid, primary key, references auth.users)
      - `name` (text)
      - `company_name` (text)
      - `role` (text, either 'sponsor' or 'organizer')
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `events`
      - `id` (uuid, primary key)
      - `name` (text)
      - `type` (text)
      - `amount` (numeric)
      - `city` (text)
      - `description` (text)
      - `date` (date)
      - `organizer_id` (uuid, references profiles)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `sponsor_profiles`
      - `id` (uuid, primary key)
      - `profile_id` (uuid, references profiles)
      - `amount` (numeric)
      - `description` (text)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `sponsor_event_types`
      - `id` (uuid, primary key)
      - `sponsor_profile_id` (uuid, references sponsor_profiles)
      - `event_type` (text)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
*/

-- Create profiles table
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  name text NOT NULL,
  company_name text NOT NULL,
  role text NOT NULL CHECK (role IN ('sponsor', 'organizer')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
  ON profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

-- Create events table
CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  type text NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0),
  city text NOT NULL,
  description text NOT NULL,
  date date NOT NULL,
  organizer_id uuid REFERENCES profiles NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Events are viewable by everyone"
  ON events
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Organizers can insert their own events"
  ON events
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'organizer'
    )
    AND organizer_id = auth.uid()
  );

CREATE POLICY "Organizers can update their own events"
  ON events
  FOR UPDATE
  TO authenticated
  USING (organizer_id = auth.uid());

-- Create sponsor_profiles table
CREATE TABLE sponsor_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid REFERENCES profiles NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0),
  description text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE sponsor_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sponsor profiles are viewable by everyone"
  ON sponsor_profiles
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Sponsors can insert their own profile"
  ON sponsor_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND role = 'sponsor'
    )
    AND profile_id = auth.uid()
  );

CREATE POLICY "Sponsors can update their own profile"
  ON sponsor_profiles
  FOR UPDATE
  TO authenticated
  USING (profile_id = auth.uid());

-- Create sponsor_event_types table
CREATE TABLE sponsor_event_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sponsor_profile_id uuid REFERENCES sponsor_profiles NOT NULL,
  event_type text NOT NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE sponsor_event_types ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Event types are viewable by everyone"
  ON sponsor_event_types
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Sponsors can insert event types"
  ON sponsor_event_types
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM sponsor_profiles
      WHERE profile_id = auth.uid()
      AND id = sponsor_event_types.sponsor_profile_id
    )
  );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_sponsor_profiles_updated_at
  BEFORE UPDATE ON sponsor_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();