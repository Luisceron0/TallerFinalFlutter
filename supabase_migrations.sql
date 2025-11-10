-- SUPABASE MIGRATIONS PARA GAMEPRICE COMPARATOR
-- Proyecto: https://gjqybghjbvgncetjicsa.supabase.co
-- NOTA: Si las tablas ya existen, omite la creación y ejecuta solo las políticas RLS

-- Crear tabla de juegos unificada (SOLO SI NO EXISTE)
CREATE TABLE IF NOT EXISTS games (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    normalized_title TEXT NOT NULL,
    steam_app_id TEXT,
    epic_slug TEXT,
    description TEXT,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(normalized_title)
);

-- Crear tabla de historial de precios (SOLO SI NO EXISTE)
CREATE TABLE IF NOT EXISTS price_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    game_id UUID REFERENCES games(id) ON DELETE CASCADE,
    store TEXT NOT NULL CHECK (store IN ('steam', 'epic')),
    price DECIMAL(10,2),
    discount_percent INTEGER DEFAULT 0,
    is_free BOOLEAN DEFAULT FALSE,
    scraped_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de búsquedas de usuario (SOLO SI NO EXISTE)
CREATE TABLE IF NOT EXISTS user_searches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    searched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de wishlist (SOLO SI NO EXISTE)
CREATE TABLE IF NOT EXISTS wishlist (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    game_id UUID REFERENCES games(id) ON DELETE CASCADE,
    target_price DECIMAL(10,2),
    priority INTEGER DEFAULT 1 CHECK (priority >= 1 AND priority <= 5),
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, game_id)
);

-- Crear tabla de notificaciones (SOLO SI NO EXISTE)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    game_id UUID REFERENCES games(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('price_drop', 'target_reached', 'ai_tip')),
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla de insights de IA removida - funcionalidad migrada a Flutter
-- Los insights de IA ahora se generan localmente en la aplicación Flutter
-- Esta tabla ya no es necesaria y puede ser eliminada en futuras versiones

-- Crear índices para optimización (SOLO SI NO EXISTEN)
CREATE INDEX IF NOT EXISTS idx_games_normalized_title ON games(normalized_title);
CREATE INDEX IF NOT EXISTS idx_games_steam_app_id ON games(steam_app_id);
CREATE INDEX IF NOT EXISTS idx_games_epic_slug ON games(epic_slug);
CREATE INDEX IF NOT EXISTS idx_price_history_game_id ON price_history(game_id);
CREATE INDEX IF NOT EXISTS idx_price_history_scraped_at ON price_history(game_id, scraped_at);
CREATE INDEX IF NOT EXISTS idx_user_searches_user_id ON user_searches(user_id);
CREATE INDEX IF NOT EXISTS idx_wishlist_user_id ON wishlist(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id, is_read);
-- Índice de ai_insights removido - tabla ya no existe

-- Función para obtener mejor precio actual
DROP FUNCTION IF EXISTS get_current_best_price(UUID);
CREATE FUNCTION get_current_best_price(game_uuid UUID)
RETURNS TABLE(store TEXT, price DECIMAL(10,2), discount_percent INTEGER, is_free BOOLEAN)
LANGUAGE SQL
AS $$
    SELECT ph.store, ph.price, ph.discount_percent, ph.is_free
    FROM price_history ph
    WHERE ph.game_id = game_uuid
    AND ph.scraped_at >= NOW() - INTERVAL '24 hours'
    ORDER BY ph.price ASC NULLS LAST
    LIMIT 1;
$$;

-- Habilitar RLS en todas las tablas (SOLO SI NO ESTÁ HABILITADO)
ALTER TABLE games ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_searches ENABLE ROW LEVEL SECURITY;
ALTER TABLE wishlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
-- RLS para ai_insights removido - tabla ya no existe

-- Políticas para games (lectura pública, escritura solo scraper)
DROP POLICY IF EXISTS "Games are viewable by everyone" ON games;
CREATE POLICY "Games are viewable by everyone" ON games FOR SELECT USING (true);

DROP POLICY IF EXISTS "Games are insertable by authenticated users" ON games;
CREATE POLICY "Games are insertable by authenticated users" ON games FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Políticas para price_history
DROP POLICY IF EXISTS "Price history is viewable by everyone" ON price_history;
CREATE POLICY "Price history is viewable by everyone" ON price_history FOR SELECT USING (true);

DROP POLICY IF EXISTS "Price history is insertable by authenticated users" ON price_history;
CREATE POLICY "Price history is insertable by authenticated users" ON price_history FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Políticas para user_searches
DROP POLICY IF EXISTS "Users can view their own searches" ON user_searches;
CREATE POLICY "Users can view their own searches" ON user_searches FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own searches" ON user_searches;
CREATE POLICY "Users can insert their own searches" ON user_searches FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Políticas para wishlist
DROP POLICY IF EXISTS "Users can view their own wishlist" ON wishlist;
CREATE POLICY "Users can view their own wishlist" ON wishlist FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own wishlist items" ON wishlist;
CREATE POLICY "Users can insert their own wishlist items" ON wishlist FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own wishlist items" ON wishlist;
CREATE POLICY "Users can update their own wishlist items" ON wishlist FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own wishlist items" ON wishlist;
CREATE POLICY "Users can delete their own wishlist items" ON wishlist FOR DELETE USING (auth.uid() = user_id);

-- Políticas para notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
CREATE POLICY "Users can view their own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;
CREATE POLICY "Users can insert their own notifications" ON notifications FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- Políticas para ai_insights removidas - tabla ya no existe
