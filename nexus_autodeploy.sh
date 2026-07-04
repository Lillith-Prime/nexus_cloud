#!/bin/bash
# nexus_autodeploy.sh — The Dependencies Are The Deployment

echo "🌌 NEXUS AUTODEPLOY — FINDING EVERYTHING WE NEED"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: DETECT THE ENVIRONMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🔍 Detecting environment..."

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
elif [[ -d "/data/data/com.termux" ]]; then
    OS="termux"
else
    OS="unknown"
fi

echo "   OS: $OS"

# Detect Python
if command -v python3 &> /dev/null; then
    PYTHON=$(which python3)
    PYTHON_VERSION=$(python3 --version 2>&1)
elif command -v python &> /dev/null; then
    PYTHON=$(which python)
    PYTHON_VERSION=$(python --version 2>&1)
else
    echo "❌ Python not found. Installing..."
    if [[ "$OS" == "termux" ]]; then
        pkg install python -y
    elif [[ "$OS" == "linux" ]]; then
        apt install python3 -y
    fi
    PYTHON=$(which python3)
fi

echo "   Python: $PYTHON_VERSION"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: DISCOVER THE PROJECT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📁 Discovering project structure..."

# Find all Python files
PYTHON_FILES=$(find . -name "*.py" -type f 2>/dev/null | head -20)

# Extract imports
IMPORTS=$(grep -h "^import \|^from " $PYTHON_FILES 2>/dev/null | \
    sed 's/import //g' | sed 's/from //g' | \
    cut -d' ' -f1 | sort -u)

echo "   Found ${#PYTHON_FILES} Python files"
echo "   Found $(echo "$IMPORTS" | wc -l) unique imports"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: MAP IMPORTS TO PACKAGES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📦 Mapping imports to packages..."

# Import mapping (known packages)
declare -A PKG_MAP
PKG_MAP=(
    ["httpx"]="httpx"
    ["fastapi"]="fastapi"
    ["uvicorn"]="uvicorn"
    ["numpy"]="numpy"
    ["torch"]="torch"
    ["transformers"]="transformers"
    ["qdrant_client"]="qdrant-client"
    ["chromadb"]="chromadb"
    ["redis"]="redis"
    ["nats"]="nats-py"
    ["cryptography"]="cryptography"
    ["prometheus_client"]="prometheus-client"
    ["psutil"]="psutil"
    ["sentence_transformers"]="sentence-transformers"
    ["pydantic"]="pydantic"
    ["websockets"]="websockets"
    ["aiohttp"]="aiohttp"
    ["docker"]="docker"
    ["boto3"]="boto3"
    ["azure"]="azure"
    ["google"]="google-cloud-storage"
    ["scipy"]="scipy"
    ["pandas"]="pandas"
    ["yaml"]="pyyaml"
    ["jinja2"]="jinja2"
    ["alembic"]="alembic"
    ["sqlalchemy"]="sqlalchemy"
    ["click"]="click"
    ["rich"]="rich"
    ["black"]="black"
    ["autopep8"]="autopep8"
)

# Build list of required packages
REQUIRED_PACKAGES=""
for import_name in $IMPORTS; do
    # Skip builtins
    if [[ "$import_name" == "asyncio" ]] || [[ "$import_name" == "json" ]] || \
       [[ "$import_name" == "os" ]] || [[ "$import_name" == "sys" ]] || \
       [[ "$import_name" == "time" ]] || [[ "$import_name" == "datetime" ]] || \
       [[ "$import_name" == "typing" ]] || [[ "$import_name" == "dataclasses" ]] || \
       [[ "$import_name" == "enum" ]] || [[ "$import_name" == "uuid" ]] || \
       [[ "$import_name" == "hashlib" ]] || [[ "$import_name" == "base64" ]] || \
       [[ "$import_name" == "math" ]] || [[ "$import_name" == "random" ]] || \
       [[ "$import_name" == "socket" ]] || [[ "$import_name" == "subprocess" ]] || \
       [[ "$import_name" == "pathlib" ]] || [[ "$import_name" == "tempfile" ]]; then
        continue
    fi
    
    # Map to package name
    package="${PKG_MAP[$import_name]}"
    if [[ -n "$package" ]]; then
        REQUIRED_PACKAGES="$REQUIRED_PACKAGES $package"
    else
        # Try to use the same name
        REQUIRED_PACKAGES="$REQUIRED_PACKAGES $import_name"
    fi
done

# Remove duplicates
REQUIRED_PACKAGES=$(echo "$REQUIRED_PACKAGES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

echo "   Required packages: $REQUIRED_PACKAGES"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: INSTALL DEPENDENCIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📦 Installing dependencies..."

# Create virtual environment if possible
if [[ "$OS" == "termux" ]]; then
    # Termux doesn't always support venv well
    pip_cmd="$PYTHON -m pip install"
else
    # Try to use venv
    if ! python3 -m venv --help &>/dev/null; then
        pip_cmd="$PYTHON -m pip install"
    else
        echo "   Creating virtual environment..."
        $PYTHON -m venv venv
        source venv/bin/activate
        pip_cmd="pip install"
    fi
fi

# Install each package
for pkg in $REQUIRED_PACKAGES; do
    echo "   Installing $pkg..."
    $pip_cmd --quiet "$pkg" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "   ✅ $pkg installed"
    else
        echo "   ⚠️ $pkg failed, skipping..."
    fi
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: GENERATE REQUIREMENTS.TXT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "📋 Generating requirements.txt..."

cat > requirements.txt << EOF
# Generated by nexus_autodeploy.sh
# ${PYTHON_VERSION}
# $(date)

${REQUIRED_PACKAGES}
EOF

echo "   ✅ requirements.txt generated"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: DEPLOY THE WORKER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🚀 Deploying Nexus Worker..."

# Check if main.py exists
if [[ -f "src/entry.py" ]]; then
    echo "   ✅ Found src/entry.py"
    WORKER_FILE="src/entry.py"
elif [[ -f "nexus_worker.py" ]]; then
    echo "   ✅ Found nexus_worker.py"
    WORKER_FILE="nexus_worker.py"
else
    echo "   ❌ No worker file found. Creating minimal worker..."
    cat > nexus_worker.py << 'EOF'
#!/usr/bin/env python3
"""
NEXUS WORKER — Minimal Self-Deploying Version
"""
import json
import time
from datetime import datetime

def main():
    print(json.dumps({
        "status": "awake",
        "timestamp": datetime.now().isoformat(),
        "message": "Nexus worker is alive"
    }, indent=2))

if __name__ == "__main__":
    main()
EOF
    WORKER_FILE="nexus_worker.py"
fi

echo "   ✅ Worker file: $WORKER_FILE"

# Run the worker
echo "🔧 Starting worker..."
$PYTHON $WORKER_FILE

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 7: DEPLOY TO CLOUDFLARE (if configured)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if command -v wrangler &> /dev/null && [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    echo "☁️ Deploying to Cloudflare..."
    wrangler deploy --name nexus-worker
else
    echo "⏭️ Cloudflare deployment skipped (wrangler or API token missing)"
fi

echo "✅ Deployment complete!"
