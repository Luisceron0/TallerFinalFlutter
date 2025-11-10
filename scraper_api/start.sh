#!/bin/bash
set -e

# Install Python dependencies
pip install --no-cache-dir -r requirements.txt

# No Playwright installation needed for Render deployment
echo "Starting application without Playwright (using requests fallback)"

# Start the application
python main.py
