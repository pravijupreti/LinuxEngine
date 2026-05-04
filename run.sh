#!/bin/bash
# run.sh - Run Jupyter Manager normally (Polkit handles privileges)

cd "$(dirname "$0")"
python3 jupyter_manager.py
