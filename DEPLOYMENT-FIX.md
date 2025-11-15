# Boganto Blog - Deployment Fix Documentation

## 🚨 Problem Summary

The Boganto Blog was experiencing multiple deployment issues:

1. **404 Errors on Static Assets** - CSS files not loading (`/blog/_next/static/css/*.css`)
2. **500 Errors on Image Optimizer** - Next.js image optimization failing
3. **403 Forbidden on API Calls** - API endpoints blocked by CloudFront/NGINX
4. **404 on API Routes** - Some API endpoints not found

## 🔧 Root Causes Identified

### 1. Missing `basePath` Configuration
Next.js was deployed at `/blog` subpath but `next.config.js` didn't have `basePath` and `assetPrefix` configured, causing:
- Static assets requested at wrong paths
- Image optimizer unable to resolve URLs correctly
- Internal routing mismatch

### 2. Image Optimizer Misconfiguration
- Missing domain allowlist for production images
- No `remotePatterns` for flexible image sources
- Rewrites not properly handling `/uploads` paths

### 3. Reverse Proxy Issues
- NGINX/CloudFront not properly routing `/api/*` to backend
- Missing CORS headers
- Incorrect origin configuration

## ✅ Solutions Implemented

### Solution 1: Fixed `next.config.js`

**File**: `frontend/next.config.js`

**Changes Made**:

```javascript
// Added basePath and assetPrefix for /blog subpath
basePath: '/blog',
assetPrefix: '/blog',

// Expanded image domains and added remotePatterns
images: {
  domains: ['localhost', 'boganto.com', 'www.boganto.com'],
  remotePatterns: [
    {
      protocol: 'https',
      hostname: 'boganto.com',
      pathname: '/uploads/**',
    },
    // ... more patterns
  ],
}

// Added API rewrites
async rewrites() {
  return [
    {
      source: '/uploads/:path*',
      destination: '(process.env.NEXT_PUBLIC_API_BASE_URL)/uploads/:path*'
    },
    {
      source: '/api/:path*',
      destination: '(process.env.NEXT_PUBLIC_API_BASE_URL)/api/:path*'
    }
  ]
}

// Added caching headers for performance
async headers() {
  return [
    {
      source: '/uploads/:path*',
      headers: [
        { key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }
      ]
    },
    // ... more headers
  ]
}
```

**Impact**:
- ✅ Static assets now load from correct `/blog/_next/...` paths
- ✅ Image optimizer can resolve image URLs
- ✅ API calls properly proxied through Next.js rewrites

### Solution 2: Created Debugging Script

**File**: `debug-deployment.sh`

**Purpose**: Comprehensive testing tool to diagnose deployment issues

**Features**:
- Tests all critical endpoints (CSS, images, API)
- Provides detailed HTTP response analysis
- Identifies CloudFront-specific issues
- Network diagnostics (DNS, traceroute)
- Color-coded output for easy issue identification

**Usage**:
```bash
# Test production deployment
./debug-deployment.sh

# Test with custom domain
DOMAIN=https://staging.boganto.com ./debug-deployment.sh
```

### Solution 3: NGINX Configuration Template

**File**: `nginx-config-sample.conf`

**Purpose**: Production-ready NGINX configuration with proper routing

**Key Features**:
- ✅ Separates `/blog/*` → Next.js and `/api/*` → PHP backend
- ✅ Serves `/uploads/*` as static files with caching
- ✅ Proper CORS headers for cross-origin requests
- ✅ Rate limiting to prevent abuse
- ✅ SSL/TLS configuration
- ✅ Security headers
- ✅ Optimized caching strategies

**Routing Logic**:
```
/blog/*           → Next.js (port 3000)
/blog/_next/*     → Next.js with aggressive caching
/blog/_next/image → Next.js image optimizer
/api/*            → PHP Backend (port 8000)
/uploads/*        → Static files (filesystem)
```

**CloudFront Alternative**: Document includes detailed CloudFront behavior configuration

## 📋 Deployment Checklist

### Pre-Deployment

- [ ] Review and update `next.config.js` with correct `basePath`
- [ ] Verify `NEXT_PUBLIC_API_BASE_URL` environment variable
- [ ] Check PHP backend is running and accessible
- [ ] Ensure `/uploads` directory has correct permissions (755)
- [ ] Verify SSL certificates are valid

### Build & Deploy

```bash
# 1. Install dependencies
cd frontend
npm install

# 2. Build production bundle
npm run build

# 3. Test build locally
npm run start
# Visit http://localhost:3000/blog

# 4. Deploy to server
rsync -avz --exclude node_modules ./ user@server:/var/www/boganto/

# 5. On server, restart services
pm2 restart all
# OR
sudo systemctl restart nginx
```

### Post-Deployment Testing

```bash
# Run diagnostic script
./debug-deployment.sh

# Check specific endpoints
curl -I https://boganto.com/blog/
curl -I https://boganto.com/api/blogs
curl -I https://boganto.com/uploads/sample.jpg

# Check logs
pm2 logs --nostream
sudo tail -f /var/log/nginx/boganto-error.log
```

### Verification

- [ ] Homepage loads at `https://boganto.com/blog/`
- [ ] CSS and JavaScript files load (check Network tab)
- [ ] Images render correctly
- [ ] API calls return data (check Console for errors)
- [ ] No 404/403/500 errors in browser console
- [ ] Admin login works
- [ ] Blog posts display correctly

## 🔍 Troubleshooting Guide

### Issue: CSS Files 404

**Symptoms**: Webpage loads but no styling, console shows `404` on `_next/static/css/*`

**Diagnosis**:
```bash
curl -I https://boganto.com/blog/_next/static/css/[hash].css
```

**Solutions**:
1. Verify `basePath: '/blog'` in `next.config.js`
2. Rebuild frontend: `cd frontend && npm run build`
3. Clear Next.js cache: `rm -rf frontend/.next`
4. Check NGINX/CloudFront routes `/blog/_next/*` to Next.js origin

### Issue: Image Optimizer 500 Error

**Symptoms**: Images don't load, console shows `500` on `_next/image?url=...`

**Diagnosis**:
```bash
# Test direct image access
curl -I https://boganto.com/uploads/image.jpg

# Test optimizer
curl -I "https://boganto.com/blog/_next/image?url=/uploads/image.jpg&w=1920&q=85"
```

**Solutions**:
1. Check `images.domains` includes `'boganto.com'`
2. Verify `remotePatterns` allows `/uploads/**`
3. Ensure `/uploads` is accessible (permissions)
4. Temporarily set `images.unoptimized: true` to bypass optimizer
5. Check Next.js server logs: `pm2 logs frontend`

### Issue: API 403 Forbidden

**Symptoms**: API calls blocked, CloudFront error page shown

**Diagnosis**:
```bash
# Test direct backend
curl -v http://localhost:8000/api/blogs

# Test through proxy
curl -v https://boganto.com/api/blogs
```

**Solutions**:

**If using NGINX**:
1. Verify `location /api/` proxies to correct backend
2. Check backend is running: `curl http://localhost:8000/health`
3. Ensure CORS headers are set
4. Check NGINX error logs: `sudo tail -f /var/log/nginx/error.log`

**If using CloudFront**:
1. Check CloudFront behavior for `/api/*` points to API origin
2. Verify "Allowed HTTP Methods" includes POST, PUT, DELETE
3. Check "Forward Headers" includes Host, Origin, Authorization
4. Disable WAF temporarily to test: AWS Console → WAF → Rules
5. Check CloudFront logs for request ID from error page

### Issue: API 404 Not Found

**Symptoms**: Specific API endpoints return 404 with Next.js error page HTML

**Diagnosis**:
```bash
# Check backend routes
cd backend
php -r "include 'server.php'; print_r(get_defined_functions());"

# Test endpoint directly
curl -v http://localhost:8000/api/banner
```

**Solutions**:
1. Verify route exists in backend (`backend/server.php` or routes file)
2. Check NGINX routes `/api/*` to backend (not frontend)
3. Ensure backend server is running: `pm2 list`
4. Check PHP error logs: `tail -f /var/log/php-fpm/error.log`

### Issue: Authentication 403

**Symptoms**: Login/auth endpoints return 403

**Solutions**:
1. Check CSRF token configuration
2. Verify session/cookie settings (domain, SameSite)
3. Ensure credentials are forwarded: `proxy_pass_header Set-Cookie`
4. Check CORS `Access-Control-Allow-Credentials: true`

## 🚀 Performance Optimization

### Caching Strategy

**Static Assets** (CSS/JS):
- Cache-Control: `public, max-age=31536000, immutable`
- Served from `/blog/_next/static/*`
- Versioned by Next.js (hash in filename)

**Images** (`/uploads/*`):
- Cache-Control: `public, max-age=31536000, immutable`
- Serve from filesystem or CDN
- Optimize with Next.js Image component

**Optimized Images** (`/_next/image`):
- Cache-Control: `public, max-age=2592000` (30 days)
- Cached by Next.js and proxy

**API Responses**:
- Cache-Control: `no-cache` or short TTL
- Never cache user-specific data

### CDN Configuration

If using CloudFront:

1. **Static Assets**: Origin = Next.js server, TTL = 1 year
2. **Uploads**: Origin = S3 or server, TTL = 1 year
3. **API**: Origin = PHP backend, TTL = 0 (no cache)
4. **Pages**: Origin = Next.js server, TTL = 1 hour (or on-demand invalidation)

### Compression

NGINX gzip enabled for:
- text/plain, text/css, text/javascript
- application/json, application/javascript
- image/svg+xml

### Rate Limiting

NGINX limits:
- API calls: 10 requests/second (burst 20)
- General requests: 30 requests/second (burst 50)

## 📊 Monitoring

### Health Checks

```bash
# Frontend health
curl https://boganto.com/blog/

# Backend health
curl https://boganto.com/api/health

# Uploads accessibility
curl -I https://boganto.com/uploads/test.jpg
```

### Log Monitoring

```bash
# NGINX access logs
sudo tail -f /var/log/nginx/boganto-access.log

# NGINX error logs
sudo tail -f /var/log/nginx/boganto-error.log

# PM2 logs (Next.js)
pm2 logs frontend --lines 100

# PM2 logs (Backend)
pm2 logs backend --lines 100
```

### Metrics to Watch

- **4xx errors**: Client errors, check frontend code
- **5xx errors**: Server errors, check backend logs
- **Response time**: Should be < 500ms for most requests
- **Cache hit ratio**: Should be > 80% for static assets

## 🔐 Security Considerations

### Headers Applied

- `X-Frame-Options: SAMEORIGIN` - Prevent clickjacking
- `X-Content-Type-Options: nosniff` - Prevent MIME sniffing
- `X-XSS-Protection: 1; mode=block` - XSS protection
- `Referrer-Policy: strict-origin-when-cross-origin` - Referrer control

### File Upload Security

- `/uploads` directory: No script execution allowed
- NGINX blocks `.php`, `.py`, `.pl`, `.sh` in uploads
- Max upload size: 20MB (configurable)

### CORS Configuration

- Allow specific origins (not wildcard `*` for credentials)
- Allow specific methods (GET, POST, PUT, DELETE)
- Allow necessary headers (Authorization, Content-Type)

## 📞 Support

### Quick Commands Reference

```bash
# Rebuild and restart
cd /var/www/boganto/frontend && npm run build && pm2 restart frontend

# Clear Next.js cache
rm -rf /var/www/boganto/frontend/.next

# Test endpoints
./debug-deployment.sh

# Check services status
pm2 status

# View logs
pm2 logs --nostream

# NGINX operations
sudo nginx -t          # Test config
sudo systemctl reload nginx
sudo systemctl status nginx
```

### Files Modified

- `frontend/next.config.js` - Main configuration fix
- `debug-deployment.sh` - New diagnostic tool
- `nginx-config-sample.conf` - New NGINX template
- `DEPLOYMENT-FIX.md` - This documentation

### Rollback Plan

If issues occur:

```bash
# 1. Switch to previous git commit
git checkout HEAD~1

# 2. Rebuild
cd frontend && npm run build

# 3. Restart services
pm2 restart all

# 4. Verify
./debug-deployment.sh
```

---

**Document Version**: 1.0  
**Last Updated**: 2024-11-15  
**Author**: GenSpark AI Developer  
