# 🎮 GamePrice Comparator - TODO List

## Phase 1: Flutter Transformation (Current)
- [x] Update app branding to "GamePrice"
- [x] Implement gaming theme (dark + neon colors)
- [x] Add chart/network dependencies (dio, fl_chart, cached_network_image)
- [x] Update auth page with gaming aesthetic
- [x] Update main.dart with dark theme

## Phase 2: Supabase Schema Setup
- [ ] Create Supabase project (free tier)
- [ ] Execute SQL migrations for game tables:
  - profiles (user profiles)
  - games (unified game catalog)
  - price_history (price tracking)
  - user_searches (AI analysis)
  - wishlist (user wishlists)
  - notifications (in-app notifications)
  - ai_insights (Gemini cache)
- [ ] Configure Row Level Security (RLS)
- [ ] Set up storage bucket for game images
- [ ] Update .env with Supabase credentials

## Phase 3: Python Scraper Backend
- [ ] Create FastAPI project structure
- [ ] Install dependencies: fastapi, uvicorn, playwright, aiohttp, beautifulsoup4
- [ ] Implement PlaywrightBaseScraper class
- [ ] Create SteamScraper with async search_game()
- [ ] Create EpicScraper with async search_game()
- [ ] Implement Supabase integration for data storage
- [ ] Create /api/search endpoint with parallel scraping
- [ ] Add rate limiting and caching
- [ ] Deploy to free hosting (Render/Railway/Fly.io)

## Phase 4: Flutter UI Overhaul
- [ ] Create Game model and PriceHistory model
- [ ] Implement ScraperApiService with Dio
- [ ] Create GameProvider with GetX
- [ ] Build search screen with game results
- [ ] Create game detail screen with price comparison
- [ ] Implement wishlist functionality
- [ ] Add price history charts with fl_chart
- [ ] Create notifications screen
- [ ] Update home menu with gaming options

## Phase 5: AI Integration
- [ ] Set up Gemini API (free tier)
- [ ] Create GeminiService in Python
- [ ] Implement user profile analysis
- [ ] Add deal quality evaluation
- [ ] Create simple tip generation
- [ ] Cache AI insights in Supabase
- [ ] Integrate AI responses in Flutter

## Phase 6: Testing & Deployment
- [ ] End-to-end testing of search flow
- [ ] Test wishlist and notifications
- [ ] Optimize scraper performance
- [ ] Deploy Flutter app to web
- [ ] Create demo video
- [ ] Update documentation

## Technical Notes
- All services must use free tiers only
- Scrapers must handle dynamic JS content
- Implement proper error handling
- Use async/await for all network operations
- Cache data to minimize API calls
- Follow clean architecture principles
