# Game Price Scraper API

API para scraping de precios de juegos en Steam y Epic Games Store.

## Despliegue en Railway

### 1. Configuración del Proyecto

1. Crea un nuevo proyecto en [Railway](https://railway.app)
2. Conecta tu repositorio de GitHub
3. Railway detectará automáticamente la configuración de Nixpacks

### 2. Variables de Entorno

Configura las siguientes variables en Railway:

```
SUPABASE_URL=tu_url_de_supabase
SUPABASE_SERVICE_KEY=tu_clave_de_servicio_de_supabase
GEMINI_API_KEY=tu_clave_de_gemini
DEBUG_MODE=false
```

### 3. Despliegue Automático

Railway construirá automáticamente la aplicación usando Nixpacks con:
- Python 3.11.9
- Playwright con Chromium
- Todas las dependencias del requirements.txt

### 4. Health Check

La API incluye un endpoint `/health` para verificar el estado del servicio.

## Desarrollo Local

```bash
# Instalar dependencias
pip install -r requirements.txt

# Instalar navegadores de Playwright
playwright install chromium

# Ejecutar la aplicación
python main.py
```

## Endpoints

- `GET /health` - Verificar estado del servicio
- `POST /search` - Buscar juegos
- `POST /details` - Obtener detalles de un juego
- `POST /wishlist/refresh` - Actualizar precios de wishlist

## Tecnologías

- FastAPI
- Playwright (para scraping dinámico)
- BeautifulSoup4 (fallback para scraping)
- Google Gemini AI (análisis de precios)
- Supabase (base de datos)
