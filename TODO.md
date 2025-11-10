# TODO: Fix Game Price Conversion and Navigation Issues

## Pending Tasks
- [x] Fix price conversion in steam_scraper.py: change usd_price / EXCHANGE_RATE to usd_price * EXCHANGE_RATE
- [x] Fix price conversion in epic_scraper.py: change eur_price / EXCHANGE_RATE to eur_price * EXCHANGE_RATE
- [x] Fix Epic price conversion in main.py: change eur_price * 0.5 to eur_price * 4500
- [x] Add 'url' field to prices dict in supabase_service.py for both Steam and Epic
- [x] Add endpoint POST /api/wishlist/add for saving games to wishlist
- [x] Configure render.yaml for automatic deployment on Render
- [x] Add addToWishlist method to ScraperApiService
- [x] Add addToWishlist method to GameRepository and GameRepositoryImpl
- [ ] Update TODO.md to mark tasks as completed
- [ ] Test API price conversions
- [ ] Test navigation buttons in Flutter app
- [ ] Test wishlist functionality
