#!/bin/bash
# Simple build script

echo "Building jupyter_manager..."

pyinstaller --onefile \
  --name jupyter_manager \
  --add-data "scripts:scripts" \
  --add-data "polkit_setup.py:." \
  --collect-all PyQt5 \
  jupyter_manager.py

if [ -f "dist/jupyter_manager" ]; then
    echo "✅ Build successful: dist/jupyter_manager"
    ls -lh dist/jupyter_manager
else
    echo "❌ Build failed"
    exit 1
fi