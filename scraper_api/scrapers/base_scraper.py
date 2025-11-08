"""
Base scraper class with fallback to requests when Playwright fails
"""
from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Any
from playwright.async_api import async_playwright, Browser, Page, BrowserContext
import asyncio
import logging
import requests
from bs4 import BeautifulSoup
from datetime import datetime

logger = logging.getLogger(__name__)


class PlaywrightBaseScraper(ABC):
    """Base class for store scrapers using Playwright with requests fallback"""

    def __init__(self, headless: bool = True):
        self.headless = headless
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.use_playwright = True  # Flag to switch to requests fallback

    async def __aenter__(self):
        """Async context manager entry"""
        try:
            await self._init_browser()
        except Exception as e:
            logger.warning(f"Playwright initialization failed: {e}. Switching to requests fallback.")
            self.use_playwright = False
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        if self.use_playwright:
            await self._close_browser()

    async def _init_browser(self):
        """Initialize Playwright browser"""
        try:
            self.playwright = await async_playwright().start()
            self.browser = await self.playwright.chromium.launch(
                headless=self.headless,
                args=[
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-accelerated-2d-canvas',
                    '--no-first-run',
                    '--no-zygote',
                    '--single-process',
                    '--disable-gpu'
                ]
            )
            self.context = await self.browser.new_context(
                viewport={'width': 1920, 'height': 1080},
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            )
            logger.info("✅ Browser initialized successfully")
        except Exception as e:
            logger.error(f"❌ Failed to initialize browser: {e}")
            raise

    async def _close_browser(self):
        """Close browser and cleanup"""
        try:
            if self.context:
                await self.context.close()
            if self.browser:
                await self.browser.close()
            if hasattr(self, 'playwright'):
                await self.playwright.stop()
            logger.info("🧹 Browser cleanup completed")
        except Exception as e:
            logger.warning(f"Browser cleanup warning: {e}")

    async def create_page(self) -> Page:
        """Create a new page with common settings"""
        if not self.context:
            raise RuntimeError("Browser context not initialized")

        page = await self.context.new_page()

        # Set timeouts
        page.set_default_timeout(30000)  # 30 seconds
        page.set_default_navigation_timeout(30000)

        # Block unnecessary resources for faster loading
        await page.route("**/*", lambda route: route.abort()
                        if route.request.resource_type in ["image", "stylesheet", "font", "media"]
                        else route.continue_())

        return page

    async def wait_for_selector_safe(self, page: Page, selector: str, timeout: int = 10000) -> bool:
        """Safely wait for selector with timeout"""
        try:
            await page.wait_for_selector(selector, timeout=timeout)
            return True
        except Exception:
            return False

    async def scroll_to_bottom(self, page: Page, max_scrolls: int = 5):
        """Scroll to bottom to trigger lazy loading"""
        for _ in range(max_scrolls):
            await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
            await asyncio.sleep(1)  # Wait for content to load

    def requests_fallback_search(self, query: str) -> List[Dict[str, Any]]:
        """Fallback search using requests when Playwright fails"""
        try:
            # This should be implemented by subclasses
            logger.info(f"Using requests fallback for query: {query}")
            return []
        except Exception as e:
            logger.error(f"Requests fallback failed: {e}")
            return []

    def requests_fallback_details(self, game_id: str) -> Dict[str, Any]:
        """Fallback details using requests when Playwright fails"""
        try:
            # This should be implemented by subclasses
            logger.info(f"Using requests fallback for game_id: {game_id}")
            return {}
        except Exception as e:
            logger.error(f"Requests fallback failed: {e}")
            return {}

    async def search_games(self, query: str) -> List[Dict[str, Any]]:
        """Search for games by query with fallback"""
        if self.use_playwright:
            try:
                return await self._search_games_playwright(query)
            except Exception as e:
                logger.warning(f"Playwright search failed: {e}. Using requests fallback.")
                self.use_playwright = False
                return self.requests_fallback_search(query)
        else:
            return self.requests_fallback_search(query)

    async def get_game_details(self, game_id: str) -> Dict[str, Any]:
        """Get detailed information for a specific game with fallback"""
        if self.use_playwright:
            try:
                return await self._get_game_details_playwright(game_id)
            except Exception as e:
                logger.warning(f"Playwright details failed: {e}. Using requests fallback.")
                self.use_playwright = False
                return self.requests_fallback_details(game_id)
        else:
            return self.requests_fallback_details(game_id)

    @abstractmethod
    async def _search_games_playwright(self, query: str) -> List[Dict[str, Any]]:
        """Search for games by query using Playwright"""
        pass

    @abstractmethod
    async def _get_game_details_playwright(self, game_id: str) -> Dict[str, Any]:
        """Get detailed information for a specific game using Playwright"""
        pass

    def normalize_price(self, price_str: str) -> Optional[float]:
        """Normalize price string to float"""
        if not price_str:
            return None

        # Remove currency symbols and convert to float
        cleaned = price_str.replace('€', '').replace('$', '').replace('£', '').strip()

        try:
            return float(cleaned)
        except ValueError:
            return None

    def extract_text_safe(self, element, default: str = "") -> str:
        """Safely extract text from element"""
        try:
            return element.text_content().strip()
        except Exception:
            return default
