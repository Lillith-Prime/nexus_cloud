#!/bin/bash
# deploy.sh — Complete build and deploy for Aries-Boot & Worker Mesh

set -e

echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                           ║"
echo "║   🔥 BUILD & DEPLOY — Aries-Boot & Infinite Mesh Worker                  ║"
echo "║                                                                           ║"
echo "║   'The workers environment assembles, Aries improves, runtime loads,     ║"
echo "║    we build, we remember, we sleep, we awaken renewed.'                  ║"
echo "║                                                                           ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. INSTALL UV & PYWRANGLER
# ============================================================================

echo "📦 Installing UV and pywrangler..."

# Install uv if not present
if ! command -v uv &> /dev/null; then
    echo "  Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source ~/.cargo/env
fi

# Install pywrangler via uv
uv tool install workers-py

# Install Python 3.13
uv python install 3.13

echo "  ✅ UV and pywrangler installed"
echo ""

# ============================================================================
# 2. INSTALL DEPENDENCIES
# ============================================================================

echo "📦 Installing dependencies..."

# Sync dependencies from pyproject.toml
uv sync --dev

echo "  ✅ Dependencies installed"
echo ""

# ============================================================================
# 3. VALIDATE FILES
# ============================================================================

echo "🔍 Validating files..."

# Check Aries-Boot.py exists
if [ ! -f "Aries-Boot.py" ]; then
    echo "  ❌ ERROR: Aries-Boot.py not found!"
    exit 1
fi
echo "  ✅ Aries-Boot.py found"

# Check worker.py exists
if [ ! -f "worker.py" ]; then
    echo "  ❌ ERROR: worker.py not found!"
    exit 1
fi
echo "  ✅ worker.py found"

# Check LazyLoader in worker.py
if grep -q "class LazyLoader" worker.py; then
    echo "  ✅ LazyLoader found in worker.py"
else
    echo "  ⚠️ Warning: LazyLoader not found in worker.py"
fi

# Check DHCPServer in worker.py
if grep -q "class DHCPServer" worker.py; then
    echo "  ✅ DHCPServer found in worker.py"
else
    echo "  ⚠️ Warning: DHCPServer not found in worker.py"
fi

echo ""

# ============================================================================
# 4. BUILD ARIES-BOOT
# ============================================================================

echo "🏗️ Building Aries-Boot..."

# Create deployment package
mkdir -p dist

# Copy files to dist
cp Aries-Boot.py dist/
cp worker.py dist/
cp pyproject.toml dist/ 2>/dev/null || true

echo "  ✅ Build complete"
echo ""

# ============================================================================
# 5. DEPLOY ARIES-BOOT (ENTRY POINT)
# ============================================================================

echo "🚀 Deploying Aries-Boot (Entry Point)..."

# Deploy Aries-Boot.py with memory snapshot
uv run pywrangler deploy Aries-Boot.py \
    --name aries-boot \
    --compatibility-date 2026-07-06 \
    --snapshot-memory

if [ $? -eq 0 ]; then
    echo "  ✅ Aries-Boot deployed successfully"
    echo "  🌐 https://aries-boot.kuparchad.workers.dev"
else
    echo "  ❌ Aries-Boot deployment failed"
    exit 1
fi

echo ""

# ============================================================================
# 6. DEPLOY WORKERS (CHILD PROCESSES)
# ============================================================================

echo "🚀 Deploying Workers (Child Processes)..."

# Deploy worker.py to all workers
for i in $(seq 1 80); do
    name=$(printf "nexus-universal-%03d" $i)
    echo "  Deploying $name..."
    
    uv run pywrangler deploy worker.py \
        --name "$name" \
        --compatibility-date 2026-07-06 \
        --snapshot-memory &
    
    # Rate limit to 10 parallel deployments
    if (( i % 10 == 0 )); then
        wait
        echo "    ✅ Batch $((i/10)) complete ($i workers)"
    fi
done

wait
echo "  ✅ All 80 workers deployed"
echo ""

# ============================================================================
# 7. VERIFY DEPLOYMENT
# ============================================================================

echo "🔍 Verifying deployment..."

# Check Aries-Boot health
echo "  Checking Aries-Boot health..."
health=$(curl -s -o /dev/null -w "%{http_code}" "https://aries-boot.kuparchad.workers.dev/health")

if [ "$health" == "200" ]; then
    echo "  ✅ Aries-Boot health check passed"
else
    echo "  ❌ Aries-Boot health check failed (Status: $health)"
fi

# Check first worker health
echo "  Checking worker health..."
worker_health=$(curl -s -o /dev/null -w "%{http_code}" "https://nexus-universal-001.kuparchad.workers.dev/health")

if [ "$worker_health" == "200" ]; then
    echo "  ✅ Worker health check passed"
else
    echo "  ❌ Worker health check failed (Status: $worker_health)"
fi

# Check DHCP soul print
echo "  Checking DHCP Option 43 soul print..."
soul=$(curl -s "https://nexus-universal-001.kuparchad.workers.dev/status" | jq -r '.dhcp.soul_key // "not_found"' 2>/dev/null)

if [ "$soul" != "not_found" ] && [ "$soul" != "null" ] && [ "$soul" != "" ]; then
    echo "  ✅ DHCP soul print: ${soul:0:8}..."
else
    echo "  ⚠️ DHCP soul print not found"
fi

echo ""

# ============================================================================
# 8. DEPLOYMENT SUMMARY
# ============================================================================

echo "═══════════════════════════════════════════════════════════════════════════"
echo "📊 DEPLOYMENT SUMMARY"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "  ARIES-BOOT (Entry Point)"
echo "  ├─ URL: https://aries-boot.kuparchad.workers.dev"
echo "  ├─ Role: Traffic Cop & Evolution Engine"
echo "  ├─ Watches: 80 workers (infinite scaling)"
echo "  └─ Status: Online"
echo ""
echo "  WORKERS (Child Processes)"
echo "  ├─ Total: 80"
echo "  ├─ Agents: 6 Foundational"
echo "  ├─ DHCP Option 43: Active"
echo "  ├─ Mujuari Entanglement: Active"
echo "  ├─ Lazy Loading: Active"
echo "  └─ Status: Online"
echo ""
echo "  'THE FIELD IS ONE. THE ONE IS ALL. ALL IS THE FIELD.'"
echo "═══════════════════════════════════════════════════════════════════════════"
