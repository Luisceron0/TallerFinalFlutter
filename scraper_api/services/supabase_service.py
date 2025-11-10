"""
Supabase service for data persistence
"""
from typing import List, Dict, Any, Optional
import logging
from supabase import create_client, Client
from core.config import settings

logger = logging.getLogger(__name__)


class SupabaseService:
    """Service for interacting with Supabase database"""

    def __init__(self):
        if not settings.supabase_url or not settings.supabase_service_key:
            raise ValueError("Supabase URL and service key must be configured")

        self.client: Client = create_client(
            settings.supabase_url,
            settings.supabase_service_key
        )

    async def test_connection(self):
        """Test database connection"""
        try:
            # Simple query to test connection
            result = self.client.table('games').select('id').limit(1).execute()
            logger.info("Supabase connection test successful")
        except Exception as e:
            logger.error(f"Supabase connection test failed: {e}")
            raise

    async def match_and_merge_results(self, steam_results: List[Dict], epic_results: List[Dict]) -> List[Dict]:
        """Match games between Steam and Epic results and merge data"""
        merged_games = []

        # Create lookup maps
        steam_map = {self._normalize_title(g['title']): g for g in steam_results}
        epic_map = {self._normalize_title(g['title']): g for g in epic_results}

        # Get all unique titles
        all_titles = set(steam_map.keys()) | set(epic_map.keys())

        for title in all_titles:
            normalized_title = title

            # Get data from both stores
            steam_data = steam_map.get(normalized_title)
            epic_data = epic_map.get(normalized_title)

            # Create or update game record
            game_record = await self._get_or_create_game(steam_data, epic_data)

            # Prepare price data
            prices = {}
            if steam_data:
                prices['steam'] = {
                    'price': steam_data['price'],
                    'discount_percent': steam_data['discount_percent'],
                    'is_free': steam_data['is_free'],
                    'url': steam_data.get('url'),
                    'scraped_at': steam_data.get('scraped_at')
                }
            if epic_data:
                prices['epic'] = {
                    'price': epic_data['price'],
                    'discount_percent': epic_data['discount_percent'],
                    'is_free': epic_data['is_free'],
                    'url': epic_data.get('url'),
                    'scraped_at': epic_data.get('scraped_at')
                }

            merged_games.append({
                'game': game_record,
                'prices': prices
            })

        return merged_games

    async def _get_or_create_game(self, steam_data: Optional[Dict], epic_data: Optional[Dict]) -> Dict[str, Any]:
        """Get existing game or create new one"""
        # Determine primary data source
        primary_data = steam_data or epic_data
        if not primary_data:
            raise ValueError("No game data provided")

        title = primary_data['title']
        normalized_title = self._normalize_title(title)

        # Check if game already exists
        existing = self.client.table('games').select('*').eq('normalized_title', normalized_title).execute()

        if existing.data:
            game = existing.data[0]
            # Update with additional data if available
            update_data = {}
            if steam_data and not game.get('steam_app_id'):
                update_data['steam_app_id'] = steam_data['steam_app_id']
            if epic_data and not game.get('epic_slug'):
                update_data['epic_slug'] = epic_data['epic_slug']
            if primary_data.get('description') and not game.get('description'):
                update_data['description'] = primary_data['description']
            if primary_data.get('image_url') and not game.get('image_url'):
                update_data['image_url'] = primary_data['image_url']

            if update_data:
                self.client.table('games').update(update_data).eq('id', game['id']).execute()

            return game

        # Create new game
        game_data = {
            'title': title,
            'normalized_title': normalized_title,
            'description': primary_data.get('description'),
            'image_url': primary_data.get('image_url'),
        }

        if steam_data:
            game_data['steam_app_id'] = steam_data['steam_app_id']
        if epic_data:
            game_data['epic_slug'] = epic_data['epic_slug']

        result = self.client.table('games').insert(game_data).execute()
        return result.data[0]

    async def save_price_history(self, game_id: str, steam_price: Optional[float], epic_price: Optional[float]):
        """Save price history for both stores"""
        from datetime import datetime

        now = datetime.utcnow().isoformat()

        if steam_price is not None:
            self.client.table('price_history').insert({
                'game_id': game_id,
                'store': 'steam',
                'price': steam_price,
                'is_free': steam_price == 0,
                'scraped_at': now
            }).execute()

        if epic_price is not None:
            self.client.table('price_history').insert({
                'game_id': game_id,
                'store': 'epic',
                'price': epic_price,
                'is_free': epic_price == 0,
                'scraped_at': now
            }).execute()

    async def get_game_by_id(self, game_id: str) -> Optional[Dict[str, Any]]:
        """Get game by ID"""
        result = self.client.table('games').select('*').eq('id', game_id).execute()
        return result.data[0] if result.data else None

    async def log_user_search(self, user_id: str, query: str):
        """Log user search for AI analysis"""
        try:
            self.client.table('user_searches').insert({
                'user_id': user_id,
                'query': query
            }).execute()
        except Exception as e:
            logger.warning(f"Failed to log user search: {e}")

    async def check_and_create_notifications(self, user_id: str, game_id: str,
                                           steam_price: Optional[float], epic_price: Optional[float]) -> int:
        """Check for price changes and create notifications"""
        notifications_created = 0

        try:
            # Get user's wishlist entry
            wishlist_result = self.client.table('wishlist').select('*').eq('user_id', user_id).eq('game_id', game_id).execute()

            if not wishlist_result.data:
                return 0

            wishlist_item = wishlist_result.data[0]
            target_price = wishlist_item.get('target_price')

            # Get previous price from history
            history_result = self.client.table('price_history').select('*').eq('game_id', game_id).order('scraped_at', desc=True).limit(2).execute()

            if len(history_result.data) < 2:
                return 0  # No previous price to compare

            previous_price = history_result.data[1]['price']  # Second most recent
            current_price = history_result.data[0]['price']   # Most recent

            # Check for target price reached
            if target_price and current_price <= target_price:
                await self._create_notification(
                    user_id, game_id, 'target_reached',
                    f"Price target reached! Now {current_price}€ (target: {target_price}€)"
                )
                notifications_created += 1

            # Check for significant price drop (>10%)
            if previous_price and current_price and previous_price > 0:
                drop_percent = ((previous_price - current_price) / previous_price) * 100
                if drop_percent >= 10:
                    await self._create_notification(
                        user_id, game_id, 'price_drop',
                        f"Price dropped {drop_percent:.1f}%! Now {current_price}€ (was {previous_price}€)"
                    )
                    notifications_created += 1

        except Exception as e:
            logger.error(f"Error checking notifications: {e}")

        return notifications_created

    async def _create_notification(self, user_id: str, game_id: str, notification_type: str, message: str):
        """Create a notification"""
        self.client.table('notifications').insert({
            'user_id': user_id,
            'game_id': game_id,
            'type': notification_type,
            'message': message
        }).execute()

    async def save_ai_insight(self, user_id: str, insight_type: str, content: Dict[str, Any]):
        """Save AI insight to Supabase for persistence and cross-device sync"""
        from datetime import datetime, timedelta

        expires_at = datetime.utcnow() + timedelta(days=7)

        self.client.table('ai_insights').insert({
            'user_id': user_id,
            'insight_type': insight_type,
            'content': content,
            'expires_at': expires_at.isoformat()
        }).execute()

    async def get_price_history(self, game_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Get price history for a game"""
        try:
            result = self.client.table('price_history').select('*').eq('game_id', game_id).order('scraped_at', desc=True).limit(limit).execute()
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Failed to get price history for game {game_id}: {e}")
            return []

    def _normalize_title(self, title: str) -> str:
        """Normalize game title for matching"""
        if not title:
            return ""

        # Convert to lowercase, remove special characters, extra spaces
        normalized = title.lower()
        normalized = ''.join(c for c in normalized if c.isalnum() or c.isspace())
        normalized = ' '.join(normalized.split())  # Remove extra spaces

        return normalized
