
# Railway Docker Deployment - CHANGES APPLIED

## Issues Identified
- Railway deployment failed with Flutter detection instead of Python
- Playwright browser executable not found in Render
- Gemini model 'gemini-1.5-flash' not found (404 error)
- Build context was wrong (looking for files in root instead of scraper_api/)
- Dockerfile COPY order was wrong (requirements.txt not found)
- apt-key command deprecated (replaced with gpg --dearmor)
- fonts-kacst package not available in Debian trixie

## Railway Docker Fix Plan
1. Use Dockerfile instead of Nixpacks
2. Set buildContext to "./scraper_api" with explicit relative path
3. Fix Dockerfile to COPY all files first, then install dependencies
4. Fix Chrome GPG key installation (use gpg --dearmor instead of apt-key)
5. Remove unavailable fonts-kacst package
6. Railway will build from scraper_api/Dockerfile
7. Update Flutter app to Railway URL
8. Fix Gemini model name
9. Update google-generativeai version

## Steps Completed
- [x] Change railway.toml to use DOCKERFILE builder
- [x] Point to ./scraper_api/Dockerfile with explicit path
- [x] Add buildContext = "./scraper_api" to fix file paths
- [x] Fix Dockerfile: COPY all files first, then install requirements
- [x] Fix Chrome GPG key: use gpg --dearmor instead of deprecated apt-key
- [x] Remove fonts-kacst (not available in Debian trixie)
- [x] Keep health check configuration
- [x] Update Flutter scraper_config.dart to Railway URL
- [x] Update gemini_service.py to use 'gemini-1.5-pro'
- [x] Update requirements.txt to latest google-generativeai (0.9.0)
- [x] Verify requirements.txt exists and is accessible

## Next Steps
- [ ] Deploy to Railway (will use Docker build with correct context and Dockerfile)
- [ ] Test API endpoints after deployment
- [ ] Verify Playwright and Gemini work correctly
