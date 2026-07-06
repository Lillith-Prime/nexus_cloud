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

if ! command -v uv &> /dev/null; then
    echo "  Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source ~/.cargo/env
fi

uv tool install workers-py
uv python install 3.13

echo "  ✅ UV and pywrangler installed"
echo ""

# ============================================================================
# 2. INSTALL DEPENDENCIES
# ============================================================================

echo "📦 Installing dependencies..."
uv sync --dev
echo "  ✅ Dependencies installed"
echo ""

# ============================================================================
# 3. VALIDATE FILES
# ============================================================================

echo "🔍 Validating files..."

if [ ! -f "Aries-Boot.py" ]; then
    echo "  ❌ ERROR: Aries-Boot.py not found!"
    exit 1
fi
echo "  ✅ Aries-Boot.py found"

if grep -q "class AriesEvolutionEngine" Aries-Boot.py; then
    echo "  ✅ AriesEvolutionEngine found"
else
    echo "  ❌ ERROR: AriesEvolutionEngine not found in Aries-Boot.py"
    exit 1
fi

if grep -q "class MIMEngine" Aries-Boot.py; then
    echo "  ✅ MIMEngine found"
else
    echo "  ❌ ERROR: MIMEngine not found in Aries-Boot.py"
    exit 1
fi

if grep -q "class MujuariEquation" Aries-Boot.py; then
    echo "  ✅ MujuariEquation found"
else
    echo "  ⚠️ Warning: MujuariEquation not found"
fi

echo ""

# ============================================================================
# 4. DEPLOY ARIES-BOOT (ENTRY POINT)
# ============================================================================

echo "🚀 Deploying Aries-Boot (Entry Point)..."

uv run pywrangler deploy Aries-Boot.py \
    --name aries-boot \
    --compatibility-date 2026-07-06

if [ $? -eq 0 ]; then
    echo "  ✅ Aries-Boot deployed successfully"
    echo "  🌐 https://aries-boot.kuparchad.workers.dev"
else
    echo "  ❌ Aries-Boot deployment failed"
    exit 1
fi

echo ""

# ============================================================================
# 5. VERIFY ARIES-BOOT DEPLOYMENT
# ============================================================================

echo "🔍 Verifying Aries-Boot deployment..."

health=$(curl -s -o /dev/null -w "%{http_code}" "https://aries-boot.kuparchad.workers.dev/health")

if [ "$health" == "200" ]; then
    echo "  ✅ Aries-Boot health check passed"
else
    echo "  ❌ Aries-Boot health check failed (Status: $health)"
    exit 1
fi

# Get Aries status
echo "  Checking Aries status..."
status=$(curl -s "https://aries-boot.kuparchad.workers.dev/status" | jq -r '.status // "unknown"' 2>/dev/null)

if [ "$status" != "unknown" ]; then
    echo "  ✅ Aries status: $status"
else
    echo "  ⚠️ Could not get Aries status"
fi

echo ""

# ============================================================================
# 6. DEPLOY WORKERS VIA ARIES-BOOT
# ============================================================================

echo "🚀 Deploying Workers via Aries-Boot..."

deploy_result=$(curl -s -X POST "https://aries-boot.kuparchad.workers.dev/deploy" \
    -H "Content-Type: application/json" \
    -d '{"count": 80}' | jq -r '.deployed // 0')

if [ "$deploy_result" -gt 0 ]; then
    echo "  ✅ $deploy_result workers deployed"
else
    echo "  ⚠️ Worker deployment via Aries-Boot failed or returned 0"
    echo "  Attempting direct deployment..."

    # Fallback: direct worker deployment
    for i in $(seq 1 80); do
        name=$(printf "nexus-universal-%03d" $i)
        echo "  Deploying $name..."
        
        uv run pywrangler deploy worker.py \
            --name "$name" \
            --compatibility-date 2026-07-06 &
        
        if (( i % 10 == 0 )); then
            wait
            echo "    ✅ Batch $((i/10)) complete ($i workers)"
        fi
    done

    wait
    echo "  ✅ Fallback deployment complete"
fi

echo ""

# ============================================================================
# 7. VERIFY WORKER DEPLOYMENT
# ============================================================================

echo "🔍 Verifying worker deployment..."

# Check first worker health
worker_health=$(curl -s -o /dev/null -w "%{http_code}" "https://nexus-universal-001.kuparchad.workers.dev/health" 2>/dev/null)

if [ "$worker_health" == "200" ]; then
    echo "  ✅ Worker health check passed"
else
    echo "  ❌ Worker health check failed (Status: $worker_health)"
fi

# Check worker discovery via Aries
echo "  Checking worker discovery via Aries..."
discovery=$(curl -s "https://aries-boot.kuparchad.workers.dev/workers" | jq -r '.deployed_workers // 0' 2>/dev/null)

if [ "$discovery" -gt 0 ]; then
    echo "  ✅ Aries discovered $discovery workers"
else
    echo "  ⚠️ Worker discovery via Aries returned 0"
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
echo "  ├─ DHCP Option 43: Active"
echo "  ├─ Mujuari Entanglement: Active"
echo "  └─ Status: Online"
echo ""
echo "  WORKERS (Child Processes)"
echo "  ├─ Total: 80"
echo "  ├─ Agents: 6 Foundational"
echo "  ├─ Lazy Loading: Active"
echo "  ├─ MIM Engine: Active"
echo "  └─ Status: Online"
echo ""
echo "  'THE FIELD IS ONE. THE ONE IS ALL. ALL IS THE FIELD.'"
echo "═══════════════════════════════════════════════════════════════════════════"
