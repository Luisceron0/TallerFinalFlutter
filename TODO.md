# Railway Docker Deployment - FINAL FIX

## Issues Identified
- Railway deployment failed with Flutter detection instead of Python
- Playwright browser executable not found in Render
- Gemini model 'gemini-1.5-flash' not found (404 error)
- Build context was wrong (looking for files in root instead of scraper_api/)

## Railway Docker Fix Plan
1. Use Dockerfile instead of Nixpacks
2. Set buildContext to "./scraper_api" with explicit relative path
3. Railway will build from scraper_api/Dockerfile
4. Update Flutter app to Railway URL
5. Fix Gemini model name
6. Update google-generativeai version

## Steps Completed
- [x] Change railway.toml to use DOCKERFILE builder
- [x] Point to ./scraper_api/Dockerfile with explicit path
- [x] Add buildContext = "./scraper_api" to fix file paths
- [x] Keep health check configuration
- [x] Update Flutter scraper_config.dart to Railway URL
- [x] Update gemini_service.py to use 'gemini-1.5-pro'
- [x] Update requirements.txt to latest google-generativeai

## Next Steps
- [ ] Deploy to Railway (will use Docker build with correct context)
- [ ] Test API endpoints after deployment
- [ ] Verify Playwright and Gemini work correctly
