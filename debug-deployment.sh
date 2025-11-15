#!/bin/bash
# Comprehensive deployment debugging script for Boganto Blog
# This script tests all critical endpoints and identifies configuration issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${DOMAIN:-https://boganto.com}"
TIMEOUT=10

echo "=================================================="
echo "🔍 Boganto Blog Deployment Diagnostic Tool"
echo "=================================================="
echo "Domain: $DOMAIN"
echo "Date: $(date)"
echo "=================================================="
echo ""

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_code="${3:-200}"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $TIMEOUT "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $response)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $response, expected $expected_code)"
        return 1
    fi
}

# Function to test with detailed output
test_detailed() {
    local name="$1"
    local url="$2"
    
    echo ""
    echo "=================================================="
    echo "📋 Detailed test: $name"
    echo "=================================================="
    echo "URL: $url"
    echo ""
    
    response=$(curl -s -i --max-time $TIMEOUT "$url" 2>&1)
    http_code=$(echo "$response" | grep -i "HTTP/" | tail -1 | awk '{print $2}')
    
    echo "HTTP Status: $http_code"
    echo ""
    echo "Response Headers:"
    echo "$response" | grep -i ":" | head -20
    echo ""
    
    if echo "$response" | grep -q "CloudFront"; then
        echo -e "${YELLOW}⚠ CloudFront detected in response${NC}"
        cloudfront_id=$(echo "$response" | grep -i "x-amz-cf-id" | cut -d: -f2 | tr -d ' \r')
        [ ! -z "$cloudfront_id" ] && echo "CloudFront Request ID: $cloudfront_id"
    fi
    
    if [ "$http_code" = "403" ] || [ "$http_code" = "500" ]; then
        echo -e "${RED}Error detected! Response body (first 500 chars):${NC}"
        echo "$response" | tail -n +$(echo "$response" | grep -n "^$" | head -1 | cut -d: -f1) | head -c 500
        echo ""
    fi
    
    echo ""
}

echo "🔹 SECTION 1: Static Assets (CSS/JS)"
echo "--------------------------------------------------"

# Test CSS asset (example from error log)
test_endpoint "CSS Asset" \
    "$DOMAIN/blog/_next/static/css/ab86e47a6972afe6.css" \
    "200"

test_endpoint "Main App (Blog Index)" \
    "$DOMAIN/blog/" \
    "200"

echo ""
echo "🔹 SECTION 2: Image Assets"
echo "--------------------------------------------------"

# Test direct upload access
test_endpoint "Direct Upload Image" \
    "$DOMAIN/uploads/1758801057_a-book-759873_640.jpg" \
    "200"

# Test Next.js image optimizer
test_endpoint "Next.js Image Optimizer" \
    "$DOMAIN/blog/_next/image?url=%2Fuploads%2F1758801057_a-book-759873_640.jpg&w=1920&q=85" \
    "200"

echo ""
echo "🔹 SECTION 3: API Endpoints"
echo "--------------------------------------------------"

# Test API endpoints
test_endpoint "API - Blogs List" \
    "$DOMAIN/api/blogs" \
    "200"

test_endpoint "API - Banner" \
    "$DOMAIN/api/banner" \
    "200"

test_endpoint "API - Categories" \
    "$DOMAIN/api/categories" \
    "200"

test_endpoint "API - Auth Login (POST endpoint)" \
    "$DOMAIN/api/auth/login" \
    "405" # Should return 405 for GET, or 400 for missing credentials

echo ""
echo "🔹 SECTION 4: Detailed Diagnostics"
echo "--------------------------------------------------"

# Perform detailed tests on problematic endpoints
test_detailed "CSS Asset (Detailed)" \
    "$DOMAIN/blog/_next/static/css/ab86e47a6972afe6.css"

test_detailed "Image Optimizer (Detailed)" \
    "$DOMAIN/blog/_next/image?url=%2Fuploads%2F1758801057_a-book-759873_640.jpg&w=1920&q=85"

test_detailed "API Blogs (Detailed)" \
    "$DOMAIN/api/blogs"

echo ""
echo "🔹 SECTION 5: Network Diagnostics"
echo "--------------------------------------------------"

echo "DNS Resolution for boganto.com:"
dig +short boganto.com A 2>/dev/null || nslookup boganto.com 2>/dev/null || echo "DNS tools not available"

echo ""
echo "Traceroute to boganto.com (first 5 hops):"
traceroute -m 5 boganto.com 2>/dev/null || echo "Traceroute not available"

echo ""
echo "=================================================="
echo "🏁 Diagnostic Complete"
echo "=================================================="
echo ""
echo "📊 Summary of Issues:"
echo ""
echo "1. CSS 404 errors → Check basePath configuration in next.config.js"
echo "2. Image 500 errors → Check image optimizer configuration & domain allowlist"
echo "3. API 403 errors → Check CloudFront behaviors and origin configuration"
echo "4. API 404 errors → Check backend routes and proxy configuration"
echo ""
echo "🔧 Quick Fixes:"
echo ""
echo "• Rebuild frontend: cd frontend && npm run build"
echo "• Restart services: pm2 restart all"
echo "• Check logs: pm2 logs --nostream"
echo ""
echo "📖 For detailed solutions, see:"
echo "   - DEPLOYMENT.md"
echo "   - NGINX-CONFIG.md"
echo "   - TROUBLESHOOTING.md"
echo ""
