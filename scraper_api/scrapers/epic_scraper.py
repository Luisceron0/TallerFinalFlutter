"""
Epic Games Store scraper using Playwright
"""
from typing import Dict, List, Optional, Any
from .base_scraper import PlaywrightBaseScraper
import logging
import re

logger = logging.getLogger(__name__)


class EpicScraper(PlaywrightBaseScraper):
    """Scraper for Epic Games Store"""

    BASE_URL = "https://store.epicgames.com"

    async def search_games(self, query: str) -> List[Dict[str, Any]]:
        """Search Epic Games store for games"""
        games = []

        try:
            page = await self.create_page()

            # Navigate to search page
            search_url = f"{self.BASE_URL}/es-ES/browse?q={query.replace(' ', '+')}&sortBy=relevancy&sortDir=DESC&count=40"
            await page.goto(search_url, wait_until="networkidle")

            # Wait for content to load (Epic uses React, so wait for specific elements)
            await self.wait_for_selector_safe(page, "[data-testid='search-results']", timeout=15000)

            # Scroll to load more results
            await self.scroll_to_bottom(page, max_scrolls=3)

            # Extract game data from React components
            games_data = await page.evaluate("""
                () => {
                    const games = [];
                    const gameCards = document.querySelectorAll('[data-testid="search-results"] [data-testid*="product-card"]');

                    for (const card of gameCards) {
                        try {
                            // Title
                            const titleElement = card.querySelector('[data-testid="product-card-title"]') ||
                                               card.querySelector('h3') ||
                                               card.querySelector('[class*="title"]');
                            const title = titleElement ? titleElement.textContent.trim() : '';

                            // Price
                            const priceElement = card.querySelector('[data-testid="product-card-price"]') ||
                                               card.querySelector('[class*="price"]');
                            const priceText = priceElement ? priceElement.textContent.trim() : 'Free';

                            // Image
                            const imgElement = card.querySelector('img');
                            const imageUrl = imgElement ? imgElement.src : null;

                            // Link to extract slug
                            const linkElement = card.querySelector('a');
                            let slug = null;
                            if (linkElement) {
                                const href = linkElement.href;
                                const slugMatch = href.match(/\\/p\\/([^\\/?]+)/);
                                slug = slugMatch ? slugMatch[1] : null;
                            }

                            // Check if it's free
                            const isFree = priceText.toLowerCase().includes('free') ||
                                         priceText === '' ||
                                         priceText.includes('Gratis');

                            if (title) {
                                games.push({
                                    title: title,
                                    epic_slug: slug,
                                    url: linkElement ? linkElement.href : null,
                                    image_url: imageUrl,
                                    price_text: priceText,
                                    is_free: isFree
                                });
                            }
                        } catch (e) {
                            console.warn('Error parsing game card:', e);
                        }
                    }

                    return games.slice(0, 10);  // Limit to first 10 results
                }
            """)

            # Process and normalize data
            for game_data in games_data:
                price = self._parse_price(game_data['price_text'])

                game = {
                    'title': game_data['title'],
                    'epic_slug': game_data['epic_slug'],
                    'url': game_data['url'],
                    'image_url': game_data['image_url'],
                    'price': price,
                    'discount_percent': 0,  # Epic doesn't show discount % easily
                    'is_free': game_data['is_free'] or price == 0,
                    'store': 'epic'
                }
                games.append(game)

            logger.info(f"Found {len(games)} games on Epic for query: {query}")

        except Exception as e:
            logger.error(f"Epic search failed for '{query}': {e}")
            raise
        finally:
            if 'page' in locals():
                await page.close()

        return games

    async def get_game_details(self, slug: str) -> Dict[str, Any]:
        """Get detailed information for a specific Epic game"""
        try:
            page = await self.create_page()

            # Navigate to game page
            game_url = f"{self.BASE_URL}/es-ES/p/{slug}"
            await page.goto(game_url, wait_until="networkidle")

            # Wait for content to load
            await self.wait_for_selector_safe(page, "[data-testid='product-title']", timeout=15000)

            # Extract detailed game data
            game_data = await page.evaluate("""
                () => {
                    // Title
                    const titleElement = document.querySelector('[data-testid="product-title"]') ||
                                       document.querySelector('h1');
                    const title = titleElement ? titleElement.textContent.trim() : '';

                    // Description
                    const descElement = document.querySelector('[data-testid="product-description"]') ||
                                      document.querySelector('[class*="description"]');
                    const description = descElement ? descElement.textContent.trim() : '';

                    // Image
                    const imgElement = document.querySelector('[data-testid="product-image"] img') ||
                                     document.querySelector('.css-1kxh8pj img') ||
                                     document.querySelector('img[alt*="game"]');
                    const imageUrl = imgElement ? imgElement.src : null;

                    // Price
                    const priceElement = document.querySelector('[data-testid="purchase-price"]') ||
                                       document.querySelector('[class*="price"]') ||
                                       document.querySelector('.css-1kxh8pj');
                    const priceText = priceElement ? priceElement.textContent.trim() : 'Free';

                    // Check if free
                    const isFree = priceText.toLowerCase().includes('free') ||
                                 priceText === '' ||
                                 priceText.includes('Gratis');

                    return {
                        title: title,
                        description: description,
                        image_url: imageUrl,
                        price_text: priceText,
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
                'discount_percent': 0,
                'is_free': game_data['is_free'] or price == 0,
                'store': 'epic'
            }

        except Exception as e:
            logger.error(f"Failed to get Epic game details for slug {slug}: {e}")
            raise
        finally:
            if 'page' in locals():
                await page.close()

    def _parse_price(self, price_text: str) -> Optional[float]:
        """Parse Epic Games price text to float"""
        if not price_text or price_text.lower() in ['free', 'gratis', '']:
            return 0.0

        # Remove currency symbols and extra text
        cleaned = re.sub(r'[€$£]', '', price_text)
        cleaned = re.sub(r'\s+', '', cleaned)

        # Epic sometimes shows ranges like "19.99 - 39.99", take the first price
        if ' - ' in cleaned:
            cleaned = cleaned.split(' - ')[0]

        try:
            return float(cleaned)
        except ValueError:
            logger.warning(f"Could not parse Epic price: {price_text}")
            return None
