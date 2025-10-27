-- =========================================
-- 🎮 GAMEPRICE COMPARATOR - SUPABASE SCHEMA
-- =========================================
-- Execute this SQL in your Supabase SQL Editor
-- Free tier: 500MB DB, 1GB storage, 2GB bandwidth/month

-- =========================================
-- 1. PROFILES TABLE (extends auth.users)
-- =========================================
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username TEXT UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- =========================================
-- 2. GAMES TABLE (unified game catalog)
-- =========================================
CREATE TABLE games (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  normalized_title TEXT NOT NULL,
  steam_app_id TEXT,
  epic_slug TEXT,
  description TEXT,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_normalized_title UNIQUE(normalized_title)
);

-- Enable RLS
ALTER TABLE games ENABLE ROW LEVEL SECURITY;

-- RLS Policies for games (public read, no write for users)
CREATE POLICY "Anyone can view games" ON games
  FOR SELECT USING (true);

-- Indexes for games
CREATE INDEX idx_games_normalized_title ON games(normalized_title);
CREATE INDEX idx_games_steam_app_id ON games(steam_app_id);
CREATE INDEX idx_games_epic_slug ON games(epic_slug);

-- =========================================
-- 3. PRICE_HISTORY TABLE
-- =========================================
CREATE TABLE price_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE,
  store TEXT NOT NULL CHECK (store IN ('steam', 'epic')),
  price DECIMAL(10,2),
  discount_percent INTEGER DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
  is_free BOOLEAN DEFAULT FALSE,
  scraped_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies for price_history (public read)
CREATE POLICY "Anyone can view price history" ON price_history
  FOR SELECT USING (true);

-- Indexes for price_history
CREATE INDEX idx_price_history_game_id ON price_history(game_id);
CREATE INDEX idx_price_history_store ON price_history(store);
CREATE INDEX idx_price_history_scraped_at ON price_history(scraped_at);

-- =========================================
-- 4. USER_SEARCHES TABLE (for AI analysis)
-- =========================================
CREATE TABLE user_searches (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  query TEXT NOT NULL,
  searched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_searches ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_searches
CREATE POLICY "Users can view own searches" ON user_searches
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own searches" ON user_searches
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Indexes for user_searches
CREATE INDEX idx_user_searches_user_id ON user_searches(user_id);
CREATE INDEX idx_user_searches_searched_at ON user_searches(searched_at);

-- =========================================
-- 5. WISHLIST TABLE
-- =========================================
CREATE TABLE wishlist (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE,
  target_price DECIMAL(10,2),
  priority INTEGER DEFAULT 3 CHECK (priority >= 1 AND priority <= 5),
  added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT unique_user_game_wishlist UNIQUE(user_id, game_id)
);

-- Enable RLS
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;

-- RLS Policies for wishlist
CREATE POLICY "Users can view own wishlist" ON wishlist
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wishlist" ON wishlist
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wishlist" ON wishlist
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own wishlist" ON wishlist
  FOR DELETE USING (auth.uid() = user_id);

-- Indexes for wishlist
CREATE INDEX idx_wishlist_user_id ON wishlist(user_id);
CREATE INDEX idx_wishlist_game_id ON wishlist(game_id);

-- =========================================
-- 6. NOTIFICATIONS TABLE (in-app notifications)
-- =========================================
CREATE TABLE notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id UUID REFERENCES games(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('price_drop', 'target_reached', 'ai_tip')),
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- System can insert notifications (will be handled by service role)
CREATE POLICY "System can insert notifications" ON notifications
  FOR INSERT WITH CHECK (true);

-- Indexes for notifications
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- =========================================
-- 7. AI_INSIGHTS TABLE (Gemini cache)
-- =========================================
CREATE TABLE ai_insights (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  insight_type TEXT NOT NULL,
  content JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '7 days')
);

-- Enable RLS
ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;

-- RLS Policies for ai_insights
CREATE POLICY "Users can view own insights" ON ai_insights
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert insights" ON ai_insights
  FOR INSERT WITH CHECK (true);

-- Indexes for ai_insights
CREATE INDEX idx_ai_insights_user_id ON ai_insights(user_id);
CREATE INDEX idx_ai_insights_expires_at ON ai_insights(expires_at);

-- =========================================
-- 8. USEFUL FUNCTIONS
-- =========================================

-- Function to get current best price for a game
CREATE OR REPLACE FUNCTION get_current_best_price(game_uuid UUID)
RETURNS TABLE(store TEXT, price DECIMAL(10,2), discount_percent INTEGER, is_free BOOLEAN, scraped_at TIMESTAMP WITH TIME ZONE)
LANGUAGE SQL
AS $$
  SELECT ph.store, ph.price, ph.discount_percent, ph.is_free, ph.scraped_at
  FROM price_history ph
  WHERE ph.game_id = game_uuid
    AND ph.scraped_at >= NOW() - INTERVAL '24 hours'
  ORDER BY
    CASE WHEN ph.is_free THEN 0 ELSE 1 END,  -- Free games first
    ph.price ASC,  -- Then by price ascending
    ph.scraped_at DESC  -- Most recent first
  LIMIT 2;  -- Return both stores
$$;

-- =========================================
-- 9. STORAGE BUCKET SETUP
-- =========================================
-- Create storage bucket for game images
INSERT INTO storage.buckets (id, name, public)
VALUES ('game-images', 'game-images', true);

-- Storage policies for game-images bucket
CREATE POLICY "Public read for game-images" ON storage.objects
  FOR SELECT USING (bucket_id = 'game-images');

-- Allow authenticated users to upload (for future admin features)
CREATE POLICY "Authenticated users can upload game images" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'game-images');

-- =========================================
-- 10. TRIGGERS FOR UPDATED_AT
-- =========================================

-- Trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers to tables with updated_at
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_games_updated_at
  BEFORE UPDATE ON games
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================
-- 11. CLEANUP FUNCTION (for old data)
-- =========================================

-- Function to clean old price history (keep last 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_price_history()
RETURNS INTEGER
LANGUAGE SQL
AS $$
  DELETE FROM price_history
  WHERE scraped_at < NOW() - INTERVAL '30 days';
  SELECT COUNT(*)::INTEGER FROM price_history;
$$;

-- =========================================
-- SETUP COMPLETE! 🎮
-- =========================================
-- Next steps:
-- 1. Copy this SQL to Supabase SQL Editor and execute
-- 2. Create .env file with your Supabase credentials
-- 3. Test the connection in Flutter
-- 4. Proceed to Phase 3: Python Scraper Backend
