# Fix Scraper API Issues

## Issues Identified
- Playwright browser executable not found due to incorrect path in render.yaml
- Gemini model 'gemini-1.5-flash' not found (404 error)

## Plan
1. Update render.yaml to remove or correct PLAYWRIGHT_BROWSERS_PATH
2. Update gemini_service.py to use 'gemini-1.5-pro' model
3. Update requirements.txt to use latest google-generativeai version
4. Test locally if possible

## Steps
- [x] Update scraper_api/render.yaml: Remove PLAYWRIGHT_BROWSERS_PATH env var
- [x] Update scraper_api/services/gemini_service.py: Change model to 'gemini-1.5-flash'
- [x] Update scraper_api/requirements.txt: Update google-generativeai to latest version
- [x] Update scraper_api/Dockerfile: Move playwright install after user creation
- [x] Run playwright install locally to ensure browsers are available
- [x] Test API endpoints to verify fixes
