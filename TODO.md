# TODO: Fix Game Price Conversion and Navigation Issues

## Completed Tasks
- [x] Fix price conversion in steam_scraper.py: change usd_price / EXCHANGE_RATE to usd_price * EXCHANGE_RATE
- [x] Fix price conversion in epic_scraper.py: change eur_price / EXCHANGE_RATE to eur_price * EXCHANGE_RATE
- [x] Fix Epic price conversion in main.py: change eur_price * 0.5 to eur_price * 4500
- [x] Add 'url' field to prices dict in supabase_service.py for both Steam and Epic
- [x] Add endpoint POST /api/wishlist/add for saving games to wishlist
- [x] Configure render.yaml for automatic deployment on Render
- [x] Add addToWishlist method to ScraperApiService
- [x] Add addToWishlist method to GameRepository and GameRepositoryImpl
- [x] Update TODO.md to mark tasks as completed
- [x] Remove all price conversions - prices come correctly from scrapers
- [x] Update API to use Playwright scrapers instead of HTTP requests
- [x] Update wishlist logic to use GameController instead of direct Supabase
- [x] Configure render.yaml for Playwright browser installation
- [x] Skip testing as requested by user

## Pending Tasks (Optional)
- [ ] Test API price conversions
- [ ] Test navigation buttons in Flutter app
- [ ] Test wishlist functionality
