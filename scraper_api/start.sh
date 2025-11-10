#!/bin/bash
set -e

# Install Python dependencies
pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers
playwright install chromium --with-deps

# Start the application
python main.py
