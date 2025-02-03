export type Park = {
  id: string;
  name: string;
  description: string | null;
  latitude: number;
  longitude: number;
  address: string | null;
  status: 'pending' | 'approved' | 'rejected';
  created_at: string;
  created_by: string;
  upvotes: number;
  downvotes: number;
};

export type ParkPhoto = {
  id: string;
  park_id: string;
  url: string;
  uploaded_by: string;
  created_at: string;
  is_approved: boolean;
};

export type ParkVote = {
  id: string;
  park_id: string;
  user_id: string;
  vote_type: boolean;
  created_at: string;
};

export type ParkComment = {
  id: string;
  park_id: string;
  user_id: string;
  content: string;
  created_at: string;
  is_reported: boolean;
};

export type ParkTag = {
  id: string;
  park_id: string;
  tag: string;
};