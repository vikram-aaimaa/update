# 🚀 Boganto Blog - Quick Fix Guide (हिंदी + English)

## तुरंत फिक्स करने के लिए (Immediate Fixes)

### 1️⃣ CSS और Static Assets 404 Fix

**समस्या**: `/blog/_next/static/css/...` पर 404 error

**तुरंत करें**:

```bash
# Step 1: Updated next.config.js already has basePath='/blog'
cd /home/user/webapp/frontend

# Step 2: Rebuild
npm run build

# Step 3: Restart
pm2 restart frontend
# या (or)
npm run start
```

**क्यों काम करेगा**: `basePath` और `assetPrefix` add किया गया है `next.config.js` में

---

### 2️⃣ Image Optimizer 500 Error Fix

**समस्या**: `/_next/image?url=/uploads/...` पर 500 error

**तुरंत करें**:

**Option A - Temporary Quick Fix** (Bypass optimizer):
```javascript
// frontend/next.config.js में temporarily add करें
images: {
  unoptimized: true,  // Add this line
}
```

**Option B - Proper Fix** (Already implemented):
```bash
# Already configured in next.config.js:
# - domains: ['boganto.com', 'www.boganto.com']
# - remotePatterns for /uploads/**

# Just rebuild:
cd frontend && npm run build && pm2 restart frontend
```

**Verify uploads accessible**:
```bash
# Check uploads folder permissions
ls -la /var/www/boganto/uploads/
chmod -R 755 /var/www/boganto/uploads/

# Test direct image access
curl -I https://boganto.com/uploads/1758801057_a-book-759873_640.jpg
```

---

### 3️⃣ API 403 Forbidden Fix

**समस्या**: `/api/...` endpoints पर 403 CloudFront error

**Diagnosis first**:
```bash
# Test backend directly
curl -v http://localhost:8000/api/blogs

# Test through domain
curl -v https://boganto.com/api/blogs
```

**अगर Direct backend works** → NGINX/CloudFront issue:

#### For NGINX Setup:

```bash
# 1. Apply the provided nginx-config-sample.conf
sudo cp /home/user/webapp/nginx-config-sample.conf /etc/nginx/sites-available/boganto.com

# 2. Create symlink if needed
sudo ln -s /etc/nginx/sites-available/boganto.com /etc/nginx/sites-enabled/

# 3. Test config
sudo nginx -t

# 4. Reload NGINX
sudo systemctl reload nginx

# 5. Verify
curl -v https://boganto.com/api/blogs
```

**Key NGINX config points**:
- `/api/*` → `proxy_pass` to backend (port 8000)
- Forward headers: Host, X-Real-IP, X-Forwarded-For
- CORS headers added
- Rate limiting configured

#### For CloudFront Setup:

```
AWS Console → CloudFront → Your Distribution

1. Origins:
   - Add origin: api.boganto.com (your backend)

2. Behaviors → Create behavior:
   - Path pattern: /api/*
   - Origin: Select API origin
   - Allowed HTTP Methods: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
   - Cache Policy: CachingDisabled
   - Origin Request Policy: AllViewer (or create custom)
   - Headers to forward: ALL or minimum [Host, Origin, Authorization]

3. WAF (if enabled):
   - Go to WAF rules
   - Check if legitimate requests are blocked
   - Temporarily disable to test

4. Test:
   curl -v https://boganto.com/api/blogs
```

---

### 4️⃣ API 404 Not Found Fix

**समस्या**: Specific endpoint (like `/api/banner`) returns 404 with Next.js HTML

**Diagnosis**:
```bash
# Check backend directly
curl -v http://localhost:8000/api/banner

# Check if backend is running
pm2 list
ps aux | grep php
```

**अगर Backend not running**:
```bash
# Start PHP backend
cd /var/www/boganto/backend
php -S 0.0.0.0:8000 server.php
# या PM2 से (or with PM2)
pm2 start "php -S 0.0.0.0:8000 server.php" --name backend
```

**अगर Backend running but 404**:
```bash
# Ensure route exists in backend
cd /var/www/boganto/backend
grep -r "banner" *.php

# Check NGINX routes /api to backend (not frontend)
sudo nginx -t
sudo cat /etc/nginx/sites-enabled/boganto.com | grep -A 10 "location /api"
```

---

### 5️⃣ Authentication 403 Fix

**समस्या**: `/api/auth/login` returns 403

**Check**:
```bash
# Test login endpoint
curl -X POST https://boganto.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"test"}'
```

**Fixes**:

1. **CORS issue**:
   - NGINX config already includes CORS headers
   - Ensure `Access-Control-Allow-Credentials: true`
   - Ensure `Access-Control-Allow-Origin` matches frontend origin

2. **CSRF issue** (for Laravel/PHP frameworks):
   ```bash
   # Check backend config
   # Ensure CSRF is disabled for API routes or token is sent
   ```

3. **Cookie/Session issue**:
   ```nginx
   # In NGINX config (already included)
   proxy_set_header Cookie $http_cookie;
   proxy_pass_header Set-Cookie;
   ```

---

## 🧪 Testing Script

**सबसे पहले यह चलाएं** (Run this first):

```bash
cd /home/user/webapp
chmod +x debug-deployment.sh
./debug-deployment.sh
```

**Output देखेगा**:
- ✓ GREEN = Working
- ✗ RED = Problem
- Detailed error info for troubleshooting

---

## 📋 Complete Fix Workflow

### Step-by-Step (सभी issues को एक साथ fix करें):

```bash
# 1. Ensure you're in correct directory
cd /home/user/webapp

# 2. Frontend rebuild with updated config
cd frontend
npm install  # If needed
npm run build

# 3. Check backend is running
pm2 list
# If backend not running:
# pm2 start ecosystem.backend.js

# 4. Apply NGINX config (if using NGINX)
sudo cp /home/user/webapp/nginx-config-sample.conf /etc/nginx/sites-available/boganto.com
sudo nginx -t
sudo systemctl reload nginx

# 5. Restart all services
pm2 restart all

# 6. Test everything
cd /home/user/webapp
./debug-deployment.sh

# 7. Check specific issues
curl -I https://boganto.com/blog/  # Should be 200
curl -I https://boganto.com/api/blogs  # Should be 200
curl -I https://boganto.com/uploads/[image-name].jpg  # Should be 200
```

---

## 🔍 Quick Diagnostic Commands

```bash
# Frontend status
pm2 info frontend

# Backend status
pm2 info backend

# NGINX status
sudo systemctl status nginx
sudo nginx -t

# Check logs
pm2 logs frontend --lines 50 --nostream
pm2 logs backend --lines 50 --nostream
sudo tail -50 /var/log/nginx/boganto-error.log

# Test endpoints
curl -v https://boganto.com/blog/
curl -v https://boganto.com/api/blogs
curl -v https://boganto.com/uploads/test.jpg
```

---

## ⚡ Emergency Rollback

अगर कुछ टूट जाए (If something breaks):

```bash
# 1. Rollback git changes
cd /home/user/webapp
git checkout HEAD~1

# 2. Rebuild
cd frontend
npm run build

# 3. Restart
pm2 restart all

# 4. Restore NGINX config
sudo systemctl reload nginx
```

---

## 📞 Issue-Solution Matrix

| Issue | Command to Test | Fix |
|-------|----------------|-----|
| CSS 404 | `curl -I https://boganto.com/blog/_next/static/css/[hash].css` | Rebuild frontend with `basePath` |
| Image 500 | `curl -I https://boganto.com/blog/_next/image?url=/uploads/img.jpg` | Check `images.domains`, rebuild |
| API 403 | `curl -v https://boganto.com/api/blogs` | Fix NGINX/CloudFront routing |
| API 404 | `curl -v http://localhost:8000/api/banner` | Check backend routes, restart |
| Auth 403 | `curl -X POST https://boganto.com/api/auth/login` | Check CORS, CSRF, sessions |

---

## 🎯 Key Files Changed

1. **`frontend/next.config.js`** - Main fix (basePath, images config)
2. **`nginx-config-sample.conf`** - Production NGINX config
3. **`debug-deployment.sh`** - Testing tool
4. **`DEPLOYMENT-FIX.md`** - Detailed documentation
5. **`QUICK-FIX-GUIDE.md`** - This guide

---

## ✅ Verification Checklist

After applying fixes:

- [ ] `https://boganto.com/blog/` loads with styling
- [ ] Images show on homepage
- [ ] API calls work (check browser Console)
- [ ] No 404/403/500 errors in Console
- [ ] Admin login works
- [ ] Blog posts display correctly

---

## 🆘 Still Having Issues?

```bash
# 1. Run full diagnostic
./debug-deployment.sh > diagnostic-output.txt

# 2. Check all logs
pm2 logs --nostream > pm2-logs.txt
sudo cat /var/log/nginx/boganto-error.log > nginx-errors.txt

# 3. Share these files for support:
#    - diagnostic-output.txt
#    - pm2-logs.txt  
#    - nginx-errors.txt
#    - Screenshot of browser Console errors
```

---

**Quick Reference Commands**:

```bash
# Rebuild everything
cd /home/user/webapp/frontend && npm run build && cd .. && pm2 restart all

# Test everything
./debug-deployment.sh

# Check status
pm2 status && sudo systemctl status nginx

# View live logs
pm2 logs
```

---

**यह काम करेगा!** (This will work!)

Just follow the steps carefully. Most issues will resolve after:
1. Rebuilding frontend (with updated `next.config.js`)
2. Applying NGINX config (properly routing `/api` and `/blog`)
3. Restarting services

Good luck! 🚀
