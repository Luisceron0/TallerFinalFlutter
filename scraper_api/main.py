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
import requests

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
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
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

class AddToWishlistRequest(BaseModel):
    user_id: str
    game_id: str
    target_price: Optional[float] = None

class AnalyzePurchaseRequest(BaseModel):
    game_id: str
    user_id: str

async def search_steam_games(query: str) -> List[Dict[str, Any]]:
    """Search Steam games using Playwright scraper"""
    try:
        from scrapers.steam_scraper import SteamScraper

        async with SteamScraper() as scraper:
            games = await scraper.search_games(query)

        return games
    except Exception as e:
        logger.error(f"Steam search failed: {e}")
        return []

async def search_epic_games(query: str) -> List[Dict[str, Any]]:
    """Search Epic Games using Playwright scraper"""
    try:
        from scrapers.epic_scraper import EpicScraper

        async with EpicScraper() as scraper:
            games = await scraper.search_games(query)

        return games
    except Exception as e:
        logger.error(f"Epic search failed: {e}")
        return []

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

        # Search both stores using simple HTTP requests
        steam_results = await search_steam_games(request.query)
        epic_results = await search_epic_games(request.query)

        # Match and merge results
        merged_results = await supabase_service.match_and_merge_results(
            steam_results, epic_results
        )

        # Ensure both prices are fetched for each game
        for game_data in merged_results:
            game = game_data['game']
            prices = game_data['prices']

            # If game has steam_app_id but no steam price, try to get it
            if game.get('steam_app_id') and not prices.get('steam'):
                try:
                    steam_url = f"https://store.steampowered.com/api/appdetails?appids={game['steam_app_id']}"
                    response = requests.get(steam_url, timeout=10)
                    if response.status_code == 200:
                        data = response.json()
                        if data.get(str(game['steam_app_id']), {}).get('success'):
                            price_info = data[str(game['steam_app_id'])].get('data', {}).get('price_overview', {})
                            steam_price = price_info.get('final', 0) / 100 if price_info else None
                            if steam_price is not None:
                                prices['steam'] = {
                                    'price': steam_price,
                                    'url': f"https://store.steampowered.com/app/{game['steam_app_id']}",
                                    'is_free': steam_price == 0,
                                    'discount_percent': price_info.get('discount_percent', 0)
                                }
                except Exception as e:
                    logger.warning(f"Failed to get Steam price for {game['steam_app_id']}: {e}")

            # If game has epic_slug but no epic price, try to get it
            if game.get('epic_slug') and not prices.get('epic'):
                try:
                    from scrapers.epic_scraper import EpicScraper
                    async with EpicScraper() as scraper:
                        epic_games = await scraper.search_games(game['title'])
                        if epic_games:
                            epic_price = epic_games[0].get('price')
                            if epic_price is not None:
                                prices['epic'] = {
                                    'price': epic_price,
                                    'url': epic_games[0].get('url'),
                                    'is_free': epic_price == 0,
                                    'discount_percent': 0
                                }
                except Exception as e:
                    logger.warning(f"Failed to get Epic price for {game['epic_slug']}: {e}")

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
                # Get game details from database
                game = await supabase_service.get_game_by_id(game_id)
                if not game:
                    continue

                # Scrape current prices using simple HTTP
                steam_price = None
                epic_price = None

                if game.get('steam_app_id'):
                    # Get Steam price
                    try:
                        steam_url = f"https://store.steampowered.com/api/appdetails?appids={game['steam_app_id']}"
                        response = requests.get(steam_url, timeout=10)
                        if response.status_code == 200:
                            data = response.json()
                            if data.get(str(game['steam_app_id']), {}).get('success'):
                                price_info = data[str(game['steam_app_id'])].get('data', {}).get('price_overview', {})
                                steam_price = price_info.get('final', 0) / 10000 if price_info else None
                    except Exception as e:
                        logger.warning(f"Failed to get Steam price for {game['steam_app_id']}: {e}")

                if game.get('epic_slug'):
                    # Get Epic price using fallback scraper
                    try:
                        from scrapers.epic_scraper import EpicScraper
                        async with EpicScraper() as scraper:
                            epic_games = await scraper.search_games(game['title'])
                            if epic_games:
                                epic_price = epic_games[0].get('price')
                    except Exception as e:
                        logger.warning(f"Failed to get Epic price for {game['epic_slug']}: {e}")

                # Also try to get Steam price if Epic failed
                if steam_price is None and game.get('steam_app_id'):
                    try:
                        steam_url = f"https://store.steampowered.com/api/appdetails?appids={game['steam_app_id']}"
                        response = requests.get(steam_url, timeout=10)
                        if response.status_code == 200:
                            data = response.json()
                            if data.get(str(game['steam_app_id']), {}).get('success'):
                                price_info = data[str(game['steam_app_id'])].get('data', {}).get('price_overview', {})
                                steam_price = price_info.get('final', 0) / 100 if price_info else None
                    except Exception as e:
                        logger.warning(f"Failed to get Steam price for {game['steam_app_id']}: {e}")

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

@app.post("/api/wishlist/add")
async def add_to_wishlist(request: AddToWishlistRequest):
    """
    Add a game to user's wishlist
    """
    try:
        logger.info(f"Adding game {request.game_id} to wishlist for user {request.user_id}")

        # Check if game exists
        game = await supabase_service.get_game_by_id(request.game_id)
        if not game:
            raise HTTPException(status_code=404, detail="Game not found")

        # Check if already in wishlist
        existing = supabase_service.client.table('wishlist').select('*').eq('user_id', request.user_id).eq('game_id', request.game_id).execute()

        if existing.data:
            # Update target price if provided
            if request.target_price is not None:
                supabase_service.client.table('wishlist').update({
                    'target_price': request.target_price
                }).eq('user_id', request.user_id).eq('game_id', request.game_id).execute()
        else:
            # Add to wishlist
            wishlist_data = {
                'user_id': request.user_id,
                'game_id': request.game_id
            }
            if request.target_price is not None:
                wishlist_data['target_price'] = request.target_price

            supabase_service.client.table('wishlist').insert(wishlist_data).execute()

        return {"message": "Game added to wishlist successfully"}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to add game to wishlist: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to add to wishlist: {str(e)}")

@app.post("/api/analyze-purchase")
async def analyze_purchase_decision(request: AnalyzePurchaseRequest):
    """
    Comprehensive AI-powered purchase decision analysis
    Returns detailed analysis with recommendation, confidence, and key factors
    """
    try:
        logger.info(f"Analyzing purchase decision for game {request.game_id} by user {request.user_id}")

        # Get game details from database
        game = await supabase_service.get_game_by_id(request.game_id)
        if not game:
            raise HTTPException(status_code=404, detail="Game not found")

        # Get current prices
        steam_price = None
        epic_price = None

        # Get Steam price
        if game.get('steam_app_id'):
            try:
                steam_url = f"https://store.steampowered.com/api/appdetails?appids={game['steam_app_id']}"
                response = requests.get(steam_url, timeout=10)
                if response.status_code == 200:
                    data = response.json()
                    if data.get(str(game['steam_app_id']), {}).get('success'):
                        price_info = data[str(game['steam_app_id'])].get('data', {}).get('price_overview', {})
                        steam_price = price_info.get('final', 0) / 100 if price_info else None
            except Exception as e:
                logger.warning(f"Failed to get Steam price for {game['steam_app_id']}: {e}")

        # Get Epic price
        if game.get('epic_slug'):
            try:
                from scrapers.epic_scraper import EpicScraper
                async with EpicScraper() as scraper:
                    epic_games = await scraper.search_games(game['title'])
                    if epic_games:
                        epic_price = epic_games[0].get('price')
            except Exception as e:
                logger.warning(f"Failed to get Epic price for {game['epic_slug']}: {e}")

        # Get price history for analysis
        price_history = await supabase_service.get_price_history(request.game_id, limit=10)

        # Generate comprehensive AI analysis
        if settings.gemini_api_key:
            analysis = await gemini_service.analyze_purchase_decision(
                game_title=game['title'],
                steam_price=steam_price,
                epic_price=epic_price,
                user_id=request.user_id,
                price_history=price_history
            )

            if analysis:
                return {
                    "game_id": request.game_id,
                    "game_title": game['title'],
                    "analysis": analysis,
                    "generated_at": datetime.utcnow().isoformat()
                }

        # Fallback response if AI is not available
        return {
            "game_id": request.game_id,
            "game_title": game['title'],
            "analysis": {
                "recommendation": "BUY_NOW",
                "confidence_score": 50,
                "summary": "AI analysis not available. Based on current prices, this appears to be a reasonable purchase.",
                "price_analysis": {
                    "best_store": "Steam" if steam_price and (not epic_price or steam_price <= epic_price) else "Epic",
                    "current_deal_quality": "Fair",
                    "price_trend": "Price trend analysis not available",
                    "savings_potential": "Unable to determine savings potential"
                },
                "user_fit_analysis": {
                    "genre_match": "Unknown",
                    "budget_alignment": "Unknown",
                    "timing_recommendation": "Buy now if interested"
                },
                "key_factors": [
                    "Current prices appear reasonable",
                    "AI analysis temporarily unavailable"
                ],
                "alternative_suggestions": []
            },
            "generated_at": datetime.utcnow().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to analyze purchase decision: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

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
    # For local development only
    import os
    port = int(os.environ.get("PORT", 8000))

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=settings.debug_mode
    )
