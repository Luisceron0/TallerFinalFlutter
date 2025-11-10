"""
Gemini AI service for price analysis and insights
Free tier: 15 requests/minute, 1500 requests/day
"""
from typing import Optional, Dict, Any, List
import logging
import google.generativeai as genai
from core.config import settings

logger = logging.getLogger(__name__)


class GeminiService:
    """Service for Gemini AI analysis"""

    def __init__(self):
        if settings.gemini_api_key:
            genai.configure(api_key=settings.gemini_api_key)
            self.model = genai.GenerativeModel('gemini-1.5-flash')
            logger.info("✅ Gemini AI service initialized")
        else:
            self.model = None
            logger.warning("⚠️  Gemini API key not configured - AI features disabled")

    async def generate_quick_tip(self, game_title: str, steam_price: Optional[float],
                               epic_price: Optional[float], user_id: str) -> Optional[str]:
        """Generate a quick tip about the game pricing"""
        if not self.model:
            return None

        try:
            # Get user's search history for context
            user_history = await self._get_user_search_history(user_id)

            prompt = f"""
            Analyze this game pricing data and provide a brief, helpful tip (max 50 words):

            Game: {game_title}
            Steam Price: {steam_price}€ (or Free)
            Epic Price: {epic_price}€ (or Free)

            User's recent searches: {', '.join(user_history[:5])}

            Focus on:
            - Best deal between stores
            - Value for money
            - Timing (if it's a good time to buy)

            Keep it concise and actionable.
            """

            response = await self.model.generate_content_async(prompt)
            tip = response.text.strip()

            # Ensure it's not too long
            if len(tip) > 100:
                tip = tip[:97] + "..."

            return tip

        except Exception as e:
            logger.error(f"Failed to generate quick tip: {e}")
            return None

    async def analyze_price_change(self, game_title: str, old_price: Optional[float],
                                 new_price: Optional[float], user_id: str) -> Optional[str]:
        """Analyze a price change and provide insight"""
        if not self.model:
            return None

        try:
            if not old_price or not new_price:
                return None

            change_percent = ((old_price - new_price) / old_price) * 100

            prompt = f"""
            Analyze this price change and give a brief insight (max 30 words):

            Game: {game_title}
            Old Price: {old_price}€
            New Price: {new_price}€
            Change: {change_percent:+.1f}%

            Is this a good deal? Should the user buy now?
            """

            response = await self.model.generate_content_async(prompt)
            return response.text.strip()

        except Exception as e:
            logger.error(f"Failed to analyze price change: {e}")
            return None

    async def analyze_user_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Analyze user's gaming preferences based on search history"""
        if not self.model:
            return None

        try:
            search_history = await self._get_user_search_history(user_id, limit=20)

            if len(search_history) < 3:
                return None  # Not enough data

            prompt = f"""
            Analyze this user's gaming search history and provide insights:

            Recent searches: {', '.join(search_history)}

            Provide a JSON response with:
            - favorite_genres: array of likely preferred genres
            - price_range: typical price range they search for
            - gaming_platforms: preferred platforms if detectable

            Keep analysis brief and data-driven.
            """

            response = await self.model.generate_content_async(prompt)

            # Try to parse JSON response
            try:
                import json
                result = json.loads(response.text)
                return result
            except:
                logger.warning("Could not parse Gemini JSON response")
                return None

        except Exception as e:
            logger.error(f"Failed to analyze user profile: {e}")
            return None

    async def evaluate_deal_quality(self, game_title: str, price: float,
                                  genre: Optional[str] = None) -> Optional[str]:
        """Evaluate if a game deal is good value"""
        if not self.model:
            return None

        try:
            prompt = f"""
            Evaluate if this is a good gaming deal (max 40 words):

            Game: {game_title}
            Current Price: {price}€
            Genre: {genre or 'Unknown'}

            Consider typical prices for this type of game.
            Is this a good deal? Why or why not?
            """

            response = await self.model.generate_content_async(prompt)
            return response.text.strip()

        except Exception as e:
            logger.error(f"Failed to evaluate deal quality: {e}")
            return None

    async def analyze_purchase_decision(self, game_title: str, steam_price: Optional[float],
                                      epic_price: Optional[float], user_id: str,
                                      price_history: List[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
        """Comprehensive purchase decision analysis using Gemini AI"""
        if not self.model:
            return None

        try:
            # Get user profile insights
            user_profile = await self.analyze_user_profile(user_id)

            # Get user's search history for context
            user_history = await self._get_user_search_history(user_id, limit=15)

            # Analyze price history if available
            price_trend = "No price history available"
            if price_history and len(price_history) > 1:
                recent_prices = [p.get('price', 0) for p in price_history[-5:] if p.get('price')]
                if recent_prices:
                    avg_price = sum(recent_prices) / len(recent_prices)
                    current_price = steam_price or epic_price
                    if current_price:
                        if current_price < avg_price:
                            price_trend = f"Current price (€{current_price:.2f}) is below average (€{avg_price:.2f}) - Good deal!"
                        elif current_price > avg_price:
                            price_trend = f"Current price (€{current_price:.2f}) is above average (€{avg_price:.2f}) - Consider waiting"
                        else:
                            price_trend = f"Current price (€{current_price:.2f}) matches average - Fair value"

            prompt = f"""
            Provide a comprehensive purchase decision analysis for this game. Return a JSON response with the following structure:

            {{
                "recommendation": "BUY_NOW" | "WAIT" | "SKIP",
                "confidence_score": 0-100,
                "summary": "Brief 2-3 sentence summary",
                "price_analysis": {{
                    "best_store": "Steam" | "Epic" | "Both",
                    "current_deal_quality": "Excellent" | "Good" | "Fair" | "Poor",
                    "price_trend": "{price_trend}",
                    "savings_potential": "Estimated savings if waiting"
                }},
                "user_fit_analysis": {{
                    "genre_match": "High" | "Medium" | "Low" | "Unknown",
                    "budget_alignment": "Within budget" | "Above budget" | "Below budget",
                    "timing_recommendation": "Buy now" | "Wait for sale" | "Skip"
                }},
                "key_factors": [
                    "Factor 1 with brief explanation",
                    "Factor 2 with brief explanation",
                    "Factor 3 with brief explanation"
                ],
                "alternative_suggestions": [
                    "Alternative game 1 if applicable",
                    "Alternative game 2 if applicable"
                ]
            }}

            Game: {game_title}
            Steam Price: {steam_price}€ (or Free)
            Epic Price: {epic_price}€ (or Free)
            Price History: {price_trend}

            User Profile: {user_profile or 'No profile data available'}
            User's Recent Searches: {', '.join(user_history[:10])}

            Consider:
            - Price comparison between stores
            - Historical price trends
            - User's gaming preferences and budget
            - Value for money
            - Timing for best deals
            - Alternative recommendations if not a good fit

            Be realistic and data-driven in your analysis.
            """

            response = await self.model.generate_content_async(prompt)

            # Try to parse JSON response
            try:
                import json
                result = json.loads(response.text.strip())
                # Validate required fields
                required_fields = ['recommendation', 'confidence_score', 'summary', 'price_analysis', 'user_fit_analysis', 'key_factors']
                if all(field in result for field in required_fields):
                    return result
                else:
                    logger.warning("AI response missing required fields")
                    return None
            except json.JSONDecodeError:
                logger.warning("Could not parse Gemini JSON response for purchase analysis")
                return None

        except Exception as e:
            logger.error(f"Failed to analyze purchase decision: {e}")
            return None

    async def _get_user_search_history(self, user_id: str, limit: int = 10) -> List[str]:
        """Get user's recent search history"""
        try:
            # This would need to be implemented with actual database access
            # For now, return empty list as placeholder
            return []
        except Exception:
            return []
