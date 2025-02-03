/*
  # Initial Schema for Calisthenics Park Locator

  1. New Tables
    - `parks`
      - `id` (uuid, primary key)
      - `name` (text)
      - `description` (text)
      - `latitude` (double precision)
      - `longitude` (double precision)
      - `address` (text)
      - `status` (enum: pending, approved, rejected)
      - `created_at` (timestamp)
      - `created_by` (uuid, references auth.users)
      - `upvotes` (integer)
      - `downvotes` (integer)
    
    - `park_photos`
      - `id` (uuid, primary key)
      - `park_id` (uuid, references parks)
      - `url` (text)
      - `uploaded_by` (uuid, references auth.users)
      - `created_at` (timestamp)
      - `is_approved` (boolean)
    
    - `park_votes`
      - `id` (uuid, primary key)
      - `park_id` (uuid, references parks)
      - `user_id` (uuid, references auth.users)
      - `vote_type` (boolean) -- true for upvote, false for downvote
      - `created_at` (timestamp)
    
    - `park_comments`
      - `id` (uuid, primary key)
      - `park_id` (uuid, references parks)
      - `user_id` (uuid, references auth.users)
      - `content` (text)
      - `created_at` (timestamp)
      - `is_reported` (boolean)
    
    - `park_tags`
      - `id` (uuid, primary key)
      - `park_id` (uuid, references parks)
      - `tag` (text)

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Add special policies for admin users
*/

-- Create custom types
CREATE TYPE park_status AS ENUM ('pending', 'approved', 'rejected');

-- Create parks table
CREATE TABLE parks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  address text,
  status park_status DEFAULT 'pending',
  created_at timestamptz DEFAULT now(),
  created_by uuid REFERENCES auth.users NOT NULL,
  upvotes integer DEFAULT 0,
  downvotes integer DEFAULT 0
);

-- Create park_photos table
CREATE TABLE park_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  park_id uuid REFERENCES parks ON DELETE CASCADE,
  url text NOT NULL,
  uploaded_by uuid REFERENCES auth.users NOT NULL,
  created_at timestamptz DEFAULT now(),
  is_approved boolean DEFAULT false
);

-- Create park_votes table
CREATE TABLE park_votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  park_id uuid REFERENCES parks ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users NOT NULL,
  vote_type boolean NOT NULL, -- true for upvote, false for downvote
  created_at timestamptz DEFAULT now(),
  UNIQUE(park_id, user_id)
);

-- Create park_comments table
CREATE TABLE park_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  park_id uuid REFERENCES parks ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users NOT NULL,
  content text NOT NULL,
  created_at timestamptz DEFAULT now(),
  is_reported boolean DEFAULT false
);

-- Create park_tags table
CREATE TABLE park_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  park_id uuid REFERENCES parks ON DELETE CASCADE,
  tag text NOT NULL
);

-- Enable Row Level Security
ALTER TABLE parks ENABLE ROW LEVEL SECURITY;
ALTER TABLE park_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE park_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE park_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE park_tags ENABLE ROW LEVEL SECURITY;

-- Create admin role
CREATE ROLE admin;

-- Parks policies
CREATE POLICY "Anyone can view approved parks"
  ON parks FOR SELECT
  USING (status = 'approved');

CREATE POLICY "Authenticated users can create parks"
  ON parks FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view their own pending parks"
  ON parks FOR SELECT
  TO authenticated
  USING (created_by = auth.uid() AND status = 'pending');

CREATE POLICY "Admins have full access to parks"
  ON parks
  TO admin
  USING (true)
  WITH CHECK (true);

-- Park photos policies
CREATE POLICY "Anyone can view approved photos"
  ON park_photos FOR SELECT
  USING (is_approved = true);

CREATE POLICY "Users can upload photos"
  ON park_photos FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view their own photos"
  ON park_photos FOR SELECT
  TO authenticated
  USING (uploaded_by = auth.uid());

CREATE POLICY "Admins have full access to photos"
  ON park_photos
  TO admin
  USING (true)
  WITH CHECK (true);

-- Park votes policies
CREATE POLICY "Authenticated users can vote"
  ON park_votes FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view their own votes"
  ON park_votes FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins have full access to votes"
  ON park_votes
  TO admin
  USING (true)
  WITH CHECK (true);

-- Park comments policies
CREATE POLICY "Anyone can view non-reported comments"
  ON park_comments FOR SELECT
  USING (NOT is_reported);

CREATE POLICY "Authenticated users can create comments"
  ON park_comments FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can view their own reported comments"
  ON park_comments FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Admins have full access to comments"
  ON park_comments
  TO admin
  USING (true)
  WITH CHECK (true);

-- Park tags policies
CREATE POLICY "Anyone can view tags"
  ON park_tags FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can add tags"
  ON park_tags FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admins have full access to tags"
  ON park_tags
  TO admin
  USING (true)
  WITH CHECK (true);

-- Create functions for vote management
CREATE OR REPLACE FUNCTION handle_park_vote()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.vote_type THEN
    UPDATE parks SET upvotes = upvotes + 1 WHERE id = NEW.park_id;
  ELSE
    UPDATE parks SET downvotes = downvotes + 1 WHERE id = NEW.park_id;
  END IF;
  
  -- Auto-approve or reject based on votes
  UPDATE parks
  SET status = CASE
    WHEN upvotes >= 10 AND (upvotes::float / (upvotes + downvotes)) >= 0.7 THEN 'approved'::park_status
    WHEN downvotes >= 5 AND (downvotes::float / (upvotes + downvotes)) >= 0.7 THEN 'rejected'::park_status
    ELSE status
  END
  WHERE id = NEW.park_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_park_vote
  AFTER INSERT ON park_votes
  FOR EACH ROW
  EXECUTE FUNCTION handle_park_vote();