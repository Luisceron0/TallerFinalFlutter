# Railway Docker Deployment

## Issues Identified
- Railway deployment failed with Flutter detection instead of Python
- Playwright browser executable not found in Render
- Gemini model 'gemini-1.5-flash' not found (404 error)

## Railway Docker Fix Plan
1. Use Dockerfile instead of Nixpacks
2. Railway will build from scraper_api/Dockerfile
3. Update Flutter app to Railway URL
4. Fix Gemini model name
5. Update google-generativeai version

## Steps Completed
- [x] Change railway.toml to use DOCKERFILE builder
- [x] Point to scraper_api/Dockerfile
- [x] Keep health check configuration
- [x] Update Flutter scraper_config.dart to Railway URL
- [x] Update gemini_service.py to use 'gemini-1.5-pro'
- [x] Update requirements.txt to latest google-generativeai

## Next Steps
- [ ] Deploy to Railway (will use Docker build)
- [ ] Test API endpoints after deployment
- [ ] Verify Playwright and Gemini work correctly
