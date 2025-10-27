"""
Steam Store scraper using Playwright
"""
from typing import Dict, List, Optional, Any
from .base_scraper import PlaywrightBaseScraper
import logging
import re

logger = logging.getLogger(__name__)


class SteamScraper(PlaywrightBaseScraper):
    """Scraper for Steam Store"""

    BASE_URL = "https://store.steampowered.com"

    async def search_games(self, query: str) -> List[Dict[str, Any]]:
        """Search Steam store for games"""
        games = []

        try:
            page = await self.create_page()

            # Navigate to search page
            search_url = f"{self.BASE_URL}/search/?term={query.replace(' ', '+')}"
            await page.goto(search_url, wait_until="networkidle")

            # Wait for search results to load
            await self.wait_for_selector_safe(page, ".search_results")

            # Extract game data
            games_data = await page.evaluate("""
                () => {
                    const games = [];
                    const rows = document.querySelectorAll('.search_result_row');

                    for (const row of rows.slice(0, 10)) {  // Limit to first 10 results
                        const titleElement = row.querySelector('.title');
                        const priceElement = row.querySelector('.discount_final_price, .search_price');
                        const discountElement = row.querySelector('.discount_pct');
                        const imgElement = row.querySelector('img');
                        const linkElement = row.querySelector('a');

                        if (titleElement) {
                            // Extract app ID from URL
                            const url = linkElement ? linkElement.href : '';
                            const appIdMatch = url.match(/app\\/(\\d+)/);
                            const appId = appIdMatch ? appIdMatch[1] : null;

                            // Check if it's a game (not DLC, software, etc.)
                            const isGame = !row.classList.contains('search_result_dlc') &&
                                         !row.classList.contains('search_result_software');

                            if (isGame) {
                                games.push({
                                    title: titleElement.textContent.trim(),
                                    app_id: appId,
                                    url: url,
                                    image_url: imgElement ? imgElement.src : null,
                                    price_text: priceElement ? priceElement.textContent.trim() : 'Free',
                                    discount_percent: discountElement ?
                                        parseInt(discountElement.textContent.replace('%', '')) : 0,
                                    is_free: priceElement ?
                                        priceElement.textContent.includes('Free') : false
                                });
                            }
                        }
                    }
                    return games;
                }
            """)

            # Process and normalize data
            for game_data in games_data:
                price = self._parse_price(game_data['price_text'])

                game = {
                    'title': game_data['title'],
                    'steam_app_id': game_data['app_id'],
                    'url': game_data['url'],
                    'image_url': game_data['image_url'],
                    'price': price,
                    'discount_percent': game_data['discount_percent'],
                    'is_free': game_data['is_free'] or price == 0,
                    'store': 'steam'
                }
                games.append(game)

            logger.info(f"Found {len(games)} games on Steam for query: {query}")

        except Exception as e:
            logger.error(f"Steam search failed for '{query}': {e}")
            raise
        finally:
            if 'page' in locals():
                await page.close()

        return games

    async def get_game_details(self, app_id: str) -> Dict[str, Any]:
        """Get detailed information for a specific Steam game"""
        try:
            page = await self.create_page()

            # Navigate to game page
            game_url = f"{self.BASE_URL}/app/{app_id}/"
            await page.goto(game_url, wait_until="networkidle")

            # Wait for content to load
            await self.wait_for_selector_safe(page, ".apphub_AppName")

            # Extract detailed game data
            game_data = await page.evaluate("""
                () => {
                    const title = document.querySelector('.apphub_AppName')?.textContent?.trim() || '';
                    const description = document.querySelector('.game_description_snippet')?.textContent?.trim() || '';
                    const image = document.querySelector('.game_header_image_full')?.src || '';

                    // Price information
                    const priceElement = document.querySelector('.discount_final_price, .price, .game_purchase_price');
                    const discountElement = document.querySelector('.discount_pct');

                    let priceText = 'Free';
                    let discountPercent = 0;
                    let isFree = false;

                    if (priceElement) {
                        priceText = priceElement.textContent.trim();
                        isFree = priceText.toLowerCase().includes('free');
                        if (discountElement) {
                            discountPercent = parseInt(discountElement.textContent.replace('%', '')) || 0;
                        }
                    }

                    return {
                        title: title,
                        description: description,
                        image_url: image,
                        price_text: priceText,
                        discount_percent: discountPercent,
                        is_free: isFree
                    };
                }
            """)

            price = self._parse_price(game_data['price_text'])

            return {
                'title': game_data['title'],
                'description': game_data['description'],
                'image_url': game_data['image_url'],
                'price': price,
                'discount_percent': game_data['discount_percent'],
                'is_free': game_data['is_free'] or price == 0,
                'store': 'steam'
            }

        except Exception as e:
            logger.error(f"Failed to get Steam game details for app {app_id}: {e}")
            raise
        finally:
            if 'page' in locals():
                await page.close()

    def _parse_price(self, price_text: str) -> Optional[float]:
        """Parse Steam price text to float"""
        if not price_text or price_text.lower() == 'free':
            return 0.0

        # Remove currency symbols and extra text
        cleaned = re.sub(r'[€$£]', '', price_text)
        cleaned = re.sub(r'\s+', '', cleaned)

        # Handle discount format like "€29.99 €39.99"
        parts = cleaned.split()
        if len(parts) >= 2:
            # Take the discounted price (first one)
            price_str = parts[0]
        else:
            price_str = cleaned

        try:
            return float(price_str)
        except ValueError:
            logger.warning(f"Could not parse price: {price_text}")
            return None
