/** @type {import('next').NextConfig} */
const nextConfig = {
  // Base path for serving the app under /blog subpath
  basePath: '/blog',
  
  // Asset prefix to ensure static assets are loaded from correct path
  assetPrefix: '/blog',
  
  reactStrictMode: true,
  
  images: {
    // Allow images from production domain and localhost
    domains: ['localhost', 'boganto.com', 'www.boganto.com'],
    
    // Use unoptimized in development for faster builds
    unoptimized: process.env.NODE_ENV === 'development',
    
    // Support remote patterns for more flexible image sources
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'boganto.com',
        pathname: '/uploads/**',
      },
      {
        protocol: 'https',
        hostname: 'www.boganto.com',
        pathname: '/uploads/**',
      },
      {
        protocol: 'http',
        hostname: 'localhost',
        pathname: '/uploads/**',
      },
    ],
    
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60,
  },
  
  async rewrites() {
    return [
      {
        // Rewrite /blog/uploads to the actual uploads location
        source: '/uploads/:path*',
        destination: (process.env.NEXT_PUBLIC_API_BASE_URL || 'https://boganto.com') + '/uploads/:path*'
      },
      {
        // Rewrite API calls to backend
        source: '/api/:path*',
        destination: (process.env.NEXT_PUBLIC_API_BASE_URL || 'https://boganto.com') + '/api/:path*'
      }
    ]
  },
  
  // Enable trailing slash for better compatibility
  trailingSlash: true,
  
  // Optimize output
  swcMinify: true,
  
  // Production optimizations
  compress: true,
  
  // Add headers for better caching
  async headers() {
    return [
      {
        source: '/uploads/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        source: '/_next/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ]
  },
}

module.exports = nextConfig