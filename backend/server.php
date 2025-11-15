<?php
// Simple PHP development server script
// This script provides a basic routing mechanism for the API endpoints

$requestUri = $_SERVER['REQUEST_URI'];
$requestMethod = $_SERVER['REQUEST_METHOD'];

// Remove query string from URI
$uri = parse_url($requestUri, PHP_URL_PATH);

// Handle CORS for all requests
// Allow specific origin for credentials support
$allowed_origins = [
    'http://localhost:5173', 
    'http://localhost:3000'
];
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if (in_array($origin, $allowed_origins)) {
    header("Access-Control-Allow-Origin: $origin");
} else {
    header("Access-Control-Allow-Origin: http://localhost:5173");
}
header("Access-Control-Allow-Credentials: true");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

// Handle preflight OPTIONS request
if ($requestMethod === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Route handling
if ($uri === '/api/blogs' || 
    preg_match('/\/api\/blogs\/(\d+)/', $uri) || 
    preg_match('/\/api\/blogs\/slug\/([^\/]+)/', $uri)) {
    // Parse the request to set proper parameters
    if (preg_match('/\/api\/blogs\/(\d+)/', $uri, $matches)) {
        $_GET['id'] = $matches[1];
    } elseif (preg_match('/\/api\/blogs\/slug\/([^\/]+)/', $uri, $matches)) {
        $_GET['slug'] = urldecode($matches[1]);
    }
    
    require_once 'getBlogs.php';
} else {
    switch ($uri) {
    
    case '/api/categories':
        require_once 'getCategories.php';
        break;
    
    case '/api/banner':
        require_once 'getBanner.php';
        break;
    
    case '/api/admin/blogs':
        require_once 'addBlog.php';
        break;
    
    case '/api/auth/login':
        require_once 'login.php';
        break;
    
    case '/api/admin/banners':
        // Admin Hero Banner management
        require_once 'adminBanners.php';
        break;
    
    case '/api/admin/related-books':
        // Admin Related Books management
        require_once 'adminRelatedBooks.php';
        break;
    
    default:
        // Check if it's a static file request from uploads directory
        if (preg_match('/\/uploads\/(.+)/', $uri, $matches)) {
            $filePath = __DIR__ . '/../uploads/' . $matches[1];
            if (file_exists($filePath)) {
                // Get file extension
                $extension = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
                
                // Map extensions to MIME types
                $mimeTypes = [
                    'jpg' => 'image/jpeg',
                    'jpeg' => 'image/jpeg',
                    'png' => 'image/png',
                    'gif' => 'image/gif',
                    'webp' => 'image/webp'
                ];
                
                // Set the content type header
                $mimeType = $mimeTypes[$extension] ?? 'application/octet-stream';
                header("Content-Type: $mimeType");
                header("Cache-Control: public, max-age=31536000");
                header("Access-Control-Allow-Origin: *");
                header("Access-Control-Allow-Methods: GET, OPTIONS");
                header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
                
                // Handle OPTIONS request for CORS preflight
                if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
                    http_response_code(200);
                    exit();
                }
                
                readfile($filePath);
                exit();
            } else {
                // File not found in uploads
                http_response_code(404);
                header('Content-Type: application/json');
                echo json_encode(['error' => 'Image not found: ' . $matches[1]]);
                exit();
            }
        }
        
        // Check if it's an assets file request
        if (preg_match('/\/assets\/(.+)/', $uri, $matches)) {
            $filePath = __DIR__ . '/../frontend/public/assets/' . $matches[1];
            if (file_exists($filePath)) {
                // Get file extension
                $extension = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
                
                // Map extensions to MIME types
                $mimeTypes = [
                    'jpg' => 'image/jpeg',
                    'jpeg' => 'image/jpeg',
                    'png' => 'image/png',
                    'gif' => 'image/gif',
                    'webp' => 'image/webp'
                ];
                
                // Set the content type header
                $mimeType = $mimeTypes[$extension] ?? 'application/octet-stream';
                header("Content-Type: $mimeType");
                header("Cache-Control: public, max-age=31536000");
                readfile($filePath);
                exit();
            } else {
                // Use default image
                $defaultImage = __DIR__ . '/../uploads/1758801057_a-book-759873_640.jpg';
                
                if (file_exists($defaultImage)) {
                    // Get file extension
                    $extension = strtolower(pathinfo($defaultImage, PATHINFO_EXTENSION));
                    
                    // Map extensions to MIME types
                    $mimeTypes = [
                        'jpg' => 'image/jpeg',
                        'jpeg' => 'image/jpeg',
                        'png' => 'image/png',
                        'gif' => 'image/gif',
                        'webp' => 'image/webp'
                    ];
                    
                    // Set the content type header
                    $mimeType = $mimeTypes[$extension] ?? 'application/octet-stream';
                    header("Content-Type: $mimeType");
                    header("Cache-Control: public, max-age=3600");
                    readfile($defaultImage);
                } else {
                    http_response_code(404);
                    header('Content-Type: application/json');
                    echo json_encode(['error' => 'Default image not found']);
                }
                exit();
            }
        }
        
        // 404 for unknown routes
        http_response_code(404);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'Route not found: ' . $uri]);
        break;
    }
}
?>