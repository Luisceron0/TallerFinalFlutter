"""
🎮 GamePrice Scraper API
FastAPI backend for scraping Steam and Epic Games prices
Free tier deployment: Render.com / Railway.app / Fly.io
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import asyncio
import logging
from datetime import datetime
import uvicorn

from scrapers.steam_scraper import SteamScraper
from scrapers.epic_scraper import EpicScraper
from services.supabase_service import SupabaseService
from services.gemini_service import GeminiService
from core.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="GamePrice Scraper API",
    description="🎮 Price comparison scraper for Steam and Epic Games",
    version="1.0.0"
)

# CORS middleware for Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
supabase_service = SupabaseService()
gemini_service = GeminiService()

# Pydantic models
class SearchRequest(BaseModel):
    query: str
    user_id: Optional[str] = None

class GameResult(BaseModel):
    id: str
    title: str
    normalized_title: str
    steam_app_id: Optional[str]
    epic_slug: Optional[str]
    description: Optional[str]
    image_url: Optional[str]
    prices: Dict[str, Any]  # {'steam': {...}, 'epic': {...}}
    ai_insight: Optional[str] = None

class SearchResponse(BaseModel):
    results: List[GameResult]
    search_time: float
    ai_enabled: bool

class RefreshWishlistRequest(BaseModel):
    user_id: str
    game_ids: List[str]

class RefreshWishlistResponse(BaseModel):
    refreshed_games: int
    notifications_created: int
    ai_insights_generated: int

@app.get("/health")
async def health_check():
    """Health check endpoint for deployment monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

@app.post("/api/search", response_model=SearchResponse)
async def search_games(request: SearchRequest, background_tasks: BackgroundTasks):
    """
    Search for games on Steam and Epic Games simultaneously
    Returns unified results with price comparison
    """
    start_time = datetime.utcnow()

    try:
        logger.info(f"Searching for: {request.query}")

        # Initialize scrapers
        steam_scraper = SteamScraper()
        epic_scraper = EpicScraper()

        # Search both stores in parallel
        steam_task = steam_scraper.search_games(request.query)
        epic_task = epic_scraper.search_games(request.query)

        steam_results, epic_results = await asyncio.gather(
            steam_task, epic_task, return_exceptions=True
        )

        # Handle exceptions
        if isinstance(steam_results, Exception):
            logger.error(f"Steam scraper error: {steam_results}")
            steam_results = []

        if isinstance(epic_results, Exception):
            logger.error(f"Epic scraper error: {epic_results}")
            epic_results = []

        # Match and merge results
        merged_results = await supabase_service.match_and_merge_results(
            steam_results, epic_results
        )

        # Convert to response format
        results = []
        for game_data in merged_results:
            game = game_data['game']
            prices = game_data['prices']

            # Generate AI insight if user provided and API key available
            ai_insight = None
            if request.user_id and settings.gemini_api_key:
                try:
                    ai_insight = await gemini_service.generate_quick_tip(
                        game_title=game['title'],
                        steam_price=prices.get('steam', {}).get('price'),
                        epic_price=prices.get('epic', {}).get('price'),
                        user_id=request.user_id
                    )
                except Exception as e:
                    logger.warning(f"AI insight generation failed: {e}")

            results.append(GameResult(
                id=game['id'],
                title=game['title'],
                normalized_title=game['normalized_title'],
                steam_app_id=game.get('steam_app_id'),
                epic_slug=game.get('epic_slug'),
                description=game.get('description'),
                image_url=game.get('image_url'),
                prices=prices,
                ai_insight=ai_insight
            ))

        # Log search for AI analysis
        if request.user_id:
            background_tasks.add_task(
                supabase_service.log_user_search,
                request.user_id,
                request.query
            )

        search_time = (datetime.utcnow() - start_time).total_seconds()

        return SearchResponse(
            results=results,
            search_time=search_time,
            ai_enabled=bool(settings.gemini_api_key)
        )

    except Exception as e:
        logger.error(f"Search failed: {e}")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")

@app.post("/api/refresh-wishlist", response_model=RefreshWishlistResponse)
async def refresh_wishlist(request: RefreshWishlistRequest, background_tasks: BackgroundTasks):
    """
    Refresh prices for games in user's wishlist
    Creates notifications for price changes and AI insights
    """
    try:
        logger.info(f"Refreshing wishlist for user: {request.user_id}")

        refreshed_count = 0
        notifications_count = 0
        ai_insights_count = 0

        for game_id in request.game_ids:
            try:
                # Get current prices from both stores
                steam_scraper = SteamScraper()
                epic_scraper = EpicScraper()

                # Get game details from database
                game = await supabase_service.get_game_by_id(game_id)
                if not game:
                    continue

                # Scrape current prices
                steam_price = None
                epic_price = None

                if game.get('steam_app_id'):
                    steam_data = await steam_scraper.get_game_details(game['steam_app_id'])
                    steam_price = steam_data.get('price')

                if game.get('epic_slug'):
                    epic_data = await epic_scraper.get_game_details(game['epic_slug'])
                    epic_price = epic_data.get('price')

                # Save new price history
                await supabase_service.save_price_history(game_id, steam_price, epic_price)

                # Check for notifications (price drops, target reached)
                notifications_created = await supabase_service.check_and_create_notifications(
                    request.user_id, game_id, steam_price, epic_price
                )
                notifications_count += notifications_created

                # Generate AI insights if enabled
                if settings.gemini_api_key:
                    insight = await gemini_service.analyze_price_change(
                        game_title=game['title'],
                        old_price=None,  # Would need to fetch from history
                        new_price=steam_price or epic_price,
                        user_id=request.user_id
                    )
                    if insight:
                        await supabase_service.save_ai_insight(
                            request.user_id, 'price_change', {'insight': insight}
                        )
                        ai_insights_count += 1

                refreshed_count += 1

            except Exception as e:
                logger.error(f"Failed to refresh game {game_id}: {e}")
                continue

        return RefreshWishlistResponse(
            refreshed_games=refreshed_count,
            notifications_created=notifications_count,
            ai_insights_generated=ai_insights_count
        )

    except Exception as e:
        logger.error(f"Wishlist refresh failed: {e}")
        raise HTTPException(status_code=500, detail=f"Refresh failed: {str(e)}")

@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("🚀 Starting GamePrice Scraper API")

    # Test Supabase connection
    try:
        await supabase_service.test_connection()
        logger.info("✅ Supabase connection successful")
    except Exception as e:
        logger.error(f"❌ Supabase connection failed: {e}")
        raise

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("🛑 Shutting down GamePrice Scraper API")

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug_mode
    )
