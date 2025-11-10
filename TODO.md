# Railway Deployment Fix

## Issues Identified
- Railway deployment failed with Flutter detection instead of Python
- Playwright browser executable not found in Render
- Gemini model 'gemini-1.5-flash' not found (404 error)

## Railway Fix Plan
1. Simplify railway.toml to use direct Python command
2. Keep Nixpacks configuration for Playwright
3. Update Flutter app back to Railway URL
4. Fix Gemini model name
5. Update google-generativeai version

## Steps Completed
- [x] Simplify railway.toml start command to "python main.py"
- [x] Keep Nixpacks phases for Playwright installation
- [x] Update Flutter scraper_config.dart back to Railway URL
- [x] Update gemini_service.py to use 'gemini-1.5-pro'
- [x] Update requirements.txt to latest google-generativeai

## Next Steps
- [ ] Deploy to Railway with simplified configuration
- [ ] Test API endpoints after deployment
- [ ] Verify Playwright and Gemini work correctly
