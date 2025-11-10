#!/bin/bash
set -e

# Install Python dependencies
pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers for Render deployment
playwright install chromium

# Start the application
python main.py
