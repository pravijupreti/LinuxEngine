# Linux Distribution - AI/ML Development Engine

This repository contains the Linux distribution version of the AI/ML Development Engine, including build scripts, runtime utilities, and Jupyter environment management.

---

## 📁 Structure

- **build/**  
  Build artifacts and intermediate files  

- **dist/**  
  Final distributable binaries/packages  

- **scripts/**  
  Supporting shell and automation scripts  

- **jupyter_manager.py**  
  Core script to manage Jupyter Notebook lifecycle  

- **jupyter_manager.spec**  
  Build specification file (used with PyInstaller or similar tools)  

- **polkit_setup.py**  
  Handles privilege configuration using PolicyKit  

- **setup_privileges.py**  
  Script to configure required system permissions  

- **run.sh**  
  Main script to start the engine  

- **build.sh**  
  Script to build the distribution  

- **clean.sh**  
  Cleans build and temporary files  

- **__pycache__/**  
  Python cache files  

---

## 🚧 Status: Prototype Phase

Currently in active development.  
Build system, privilege management, and runtime execution are being refined.

Future improvements will include:
- Modular architecture separation  
- Improved packaging and distribution  
- Enhanced cross-platform compatibility  

---

## ⚡ Quick Start

### 🐧 Linux

```bash
# Build the project
./build.sh

# Run the engine
./run.sh

# (Optional) Clean build files
./clean.sh
🔐 Permissions Setup

Some features require elevated privileges. Run:

python3 setup_privileges.py

or

python3 polkit_setup.py

(depending on your system configuration)

🧠 Notes
Designed for Linux-based environments
Integrates Jupyter Notebook management
Uses system-level permissions for advanced control
