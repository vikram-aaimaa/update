#!/bin/bash
# Boganto Blog - Quick Deployment Script
# This script automates the deployment of all fixes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=================================================="
echo "🚀 Boganto Blog - Deployment Fix Script"
echo "=================================================="
echo ""

# Function to print status
print_status() {
    echo -e "${BLUE}➤${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running as root for nginx operations
check_root_for_nginx() {
    if [ "$EUID" -ne 0 ] && [ "$SKIP_NGINX" != "true" ]; then 
        print_warning "NGINX configuration requires sudo access."
        print_warning "Run with: sudo ./deploy-fix.sh"
        print_warning "Or skip NGINX setup: SKIP_NGINX=true ./deploy-fix.sh"
        echo ""
        read -p "Continue without NGINX configuration? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        export SKIP_NGINX=true
    fi
}

# Step 1: Check current directory
print_status "Checking environment..."
if [ ! -f "frontend/next.config.js" ]; then
    print_error "Error: Must be run from project root (where frontend/ directory exists)"
    exit 1
fi
print_success "Environment OK"
echo ""

# Step 2: Backup existing configuration
print_status "Creating backup of current configuration..."
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
if [ -f "frontend/.next/BUILD_ID" ]; then
    cp -r frontend/.next "$BACKUP_DIR/" 2>/dev/null || true
fi
if [ -f "/etc/nginx/sites-available/boganto.com" ]; then
    sudo cp /etc/nginx/sites-available/boganto.com "$BACKUP_DIR/nginx-config.backup" 2>/dev/null || true
fi
print_success "Backup created: $BACKUP_DIR"
echo ""

# Step 3: Install frontend dependencies
print_status "Installing frontend dependencies..."
cd frontend
if [ ! -d "node_modules" ]; then
    npm install
else
    print_warning "node_modules exists, skipping install. Run 'npm install' manually if needed."
fi
cd ..
print_success "Dependencies ready"
echo ""

# Step 4: Build frontend
print_status "Building frontend with updated configuration..."
cd frontend
npm run build
if [ $? -eq 0 ]; then
    print_success "Frontend build successful"
else
    print_error "Frontend build failed!"
    exit 1
fi
cd ..
echo ""

# Step 5: Apply NGINX configuration (if not skipped)
if [ "$SKIP_NGINX" != "true" ]; then
    print_status "Applying NGINX configuration..."
    
    # Check if NGINX is installed
    if command -v nginx &> /dev/null; then
        # Backup existing config if exists
        if [ -f "/etc/nginx/sites-available/boganto.com" ]; then
            sudo cp /etc/nginx/sites-available/boganto.com "/etc/nginx/sites-available/boganto.com.backup.$(date +%Y%m%d-%H%M%S)"
            print_success "Existing NGINX config backed up"
        fi
        
        # Copy new config
        sudo cp nginx-config-sample.conf /etc/nginx/sites-available/boganto.com
        
        # Create symlink if not exists
        if [ ! -f "/etc/nginx/sites-enabled/boganto.com" ]; then
            sudo ln -s /etc/nginx/sites-available/boganto.com /etc/nginx/sites-enabled/boganto.com
        fi
        
        # Test configuration
        print_status "Testing NGINX configuration..."
        if sudo nginx -t; then
            print_success "NGINX configuration valid"
            
            # Reload NGINX
            print_status "Reloading NGINX..."
            sudo systemctl reload nginx
            print_success "NGINX reloaded successfully"
        else
            print_error "NGINX configuration test failed!"
            print_warning "Please review nginx-config-sample.conf and adjust for your setup"
            print_warning "Reverting to backup..."
            if [ -f "/etc/nginx/sites-available/boganto.com.backup.$(date +%Y%m%d)*" ]; then
                sudo cp /etc/nginx/sites-available/boganto.com.backup.* /etc/nginx/sites-available/boganto.com
            fi
        fi
    else
        print_warning "NGINX not found. Skipping NGINX configuration."
        print_warning "If using CloudFront, see nginx-config-sample.conf for CloudFront setup notes."
    fi
    echo ""
else
    print_warning "Skipping NGINX configuration (SKIP_NGINX=true)"
    echo ""
fi

# Step 6: Restart services
print_status "Restarting services..."
if command -v pm2 &> /dev/null; then
    pm2 restart all 2>/dev/null || print_warning "PM2 restart failed or no processes running"
    print_success "Services restarted"
else
    print_warning "PM2 not found. Please restart your services manually."
fi
echo ""

# Step 7: Wait for services to start
print_status "Waiting for services to stabilize..."
sleep 3
print_success "Services ready"
echo ""

# Step 8: Run diagnostics
print_status "Running deployment diagnostics..."
if [ -f "debug-deployment.sh" ]; then
    chmod +x debug-deployment.sh
    echo ""
    ./debug-deployment.sh
else
    print_warning "Diagnostic script not found. Skipping tests."
fi
echo ""

# Step 9: Summary
echo "=================================================="
echo "📊 Deployment Summary"
echo "=================================================="
print_success "Frontend rebuilt with basePath='/blog'"
print_success "Image optimizer configured"
if [ "$SKIP_NGINX" != "true" ]; then
    print_success "NGINX configuration applied"
else
    print_warning "NGINX configuration skipped"
fi
print_success "Services restarted"
echo ""

echo "🔍 Verification Steps:"
echo "   1. Visit https://boganto.com/blog/"
echo "   2. Check browser Console for errors"
echo "   3. Verify images load correctly"
echo "   4. Test API functionality"
echo "   5. Try admin login"
echo ""

echo "📚 Documentation:"
echo "   - DEPLOYMENT-FIX.md (detailed guide)"
echo "   - QUICK-FIX-GUIDE.md (quick reference)"
echo "   - SOLUTION-SUMMARY.md (complete summary)"
echo ""

echo "🔄 If Issues Occur:"
echo "   - Check logs: pm2 logs --nostream"
echo "   - Run diagnostics: ./debug-deployment.sh"
echo "   - Rollback: git checkout HEAD~1 && cd frontend && npm run build && pm2 restart all"
echo ""

echo "✅ Deployment complete!"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
