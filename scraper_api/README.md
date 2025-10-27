# 🎮 GamePrice Scraper API

FastAPI backend for scraping Steam and Epic Games prices with AI insights.

## Features

- **Parallel Scraping**: Search Steam and Epic Games simultaneously
- **Playwright Integration**: Handles dynamic JavaScript content
- **Supabase Storage**: PostgreSQL database with real-time capabilities
- **Gemini AI**: Price analysis and personalized tips (free tier)
- **Docker Ready**: Easy deployment to free hosting platforms
- **Async/Await**: High-performance concurrent operations

## Tech Stack

- **Framework**: FastAPI + Uvicorn
- **Scraping**: Playwright + AsyncIO
- **Database**: Supabase (PostgreSQL)
- **AI**: Google Gemini 1.5 Flash (free tier)
- **Deployment**: Docker + Free hosting (Render/Railway/Fly.io)

## Quick Start

### 1. Clone and Setup

```bash
cd scraper_api
cp .env.example .env
# Edit .env with your API keys
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
playwright install chromium
```

### 3. Run Locally

```bash
uvicorn main:app --reload
```

### 4. Test API

```bash
curl "http://localhost:8000/health"
```

## API Endpoints

### GET /health
Health check endpoint.

### POST /api/search
Search for games across Steam and Epic.

**Request:**
```json
{
  "query": "elden ring",
  "user_id": "optional-user-uuid"
}
```

**Response:**
```json
{
  "results": [
    {
      "id": "game-uuid",
      "title": "Elden Ring",
      "normalized_title": "elden ring",
      "steam_app_id": "1245620",
      "epic_slug": "elden-ring",
      "description": "Game description...",
      "image_url": "https://...",
      "prices": {
        "steam": {
          "price": 59.99,
          "discount_percent": 0,
          "is_free": false,
          "scraped_at": "2024-01-01T12:00:00Z"
        },
        "epic": {
          "price": 39.99,
          "discount_percent": 33,
          "is_free": false,
          "scraped_at": "2024-01-01T12:00:00Z"
        }
      },
      "ai_insight": "Epic Games has the best deal at 33% off!"
    }
  ],
  "search_time": 2.34,
  "ai_enabled": true
}
```

### POST /api/refresh-wishlist
Refresh prices for user's wishlist games.

**Request:**
```json
{
  "user_id": "user-uuid",
  "game_ids": ["game-uuid-1", "game-uuid-2"]
}
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Your Supabase project URL | Yes |
| `SUPABASE_SERVICE_KEY` | Supabase service role key | Yes |
| `GEMINI_API_KEY` | Google Gemini API key | No (AI features disabled) |
| `DEBUG_MODE` | Enable debug logging | No |

## Deployment

### Docker Build

```bash
docker build -t gameprice-scraper .
docker run -p 8000:8000 --env-file .env gameprice-scraper
```

### Free Hosting Options

#### Render.com (750 hours free/month)
1. Connect GitHub repo
2. Set build command: `pip install -r requirements.txt && playwright install chromium`
3. Set start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

#### Railway.app (500 hours free/month)
1. Connect repo
2. Set build command: `pip install -r requirements.txt`
3. Set start command: `playwright install chromium && uvicorn main:app --host 0.0.0.0 --port $PORT`

#### Fly.io (3 free VMs)
1. Install flyctl
2. `fly launch`
3. `fly deploy`

## Architecture

```
scraper_api/
├── main.py              # FastAPI app & routes
├── core/
│   └── config.py        # Settings & configuration
├── scrapers/
│   ├── base_scraper.py  # Playwright base class
│   ├── steam_scraper.py # Steam Store scraper
│   └── epic_scraper.py  # Epic Games scraper
└── services/
    ├── supabase_service.py  # Database operations
    └── gemini_service.py    # AI analysis
```

## Rate Limits & Free Tiers

- **Gemini AI**: 15 req/min, 1500 req/day
- **Steam**: ~20 req/min (be respectful)
- **Epic**: ~20 req/min (be respectful)
- **Supabase**: 500MB DB, 1GB storage free

## Development

### Running Tests

```bash
# Install test dependencies
pip install pytest httpx

# Run tests
pytest
```

### Code Quality

```bash
# Format code
black .

# Lint code
flake8 .

# Type checking
mypy .
```

## Troubleshooting

### Playwright Issues
```bash
# Reinstall browsers
playwright install chromium

# Check installation
playwright --version
```

### Supabase Connection
```bash
# Test connection
python -c "from services.supabase_service import SupabaseService; s = SupabaseService(); s.test_connection()"
```

### Common Errors

- **Browser launch failed**: Ensure Docker has proper permissions or use `--no-sandbox`
- **CAPTCHA blocked**: Steam may block aggressive scraping
- **Rate limited**: Add delays between requests
- **Memory issues**: Playwright browsers are memory-intensive

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new features
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - Free for educational and personal use.
