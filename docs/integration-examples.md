# Integration Examples

This document provides practical examples of how to integrate different types of applications with our centralized infrastructure.

## 🐍 Python/Django Application

### docker-compose.yml
```yaml
version: '3.8'

services:
  django-app:
    build: .
    container_name: django-app-container
    environment:
      # Django Database Configuration
      DB_ENGINE: django.db.backends.postgresql
      DB_NAME: django_app
      DB_USER: postgres
      DB_PASSWORD: postgres123
      DB_HOST: postgres
      DB_PORT: 5432
      
      # Redis for caching/sessions
      REDIS_URL: redis://:redis123@redis:6379/1
      
      # Django Settings
      DEBUG: "False"
      SECRET_KEY: your-secret-key-here
      ALLOWED_HOSTS: django-app.localhost,localhost
      
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.django-app.rule=Host(`django-app.localhost`)"
      - "traefik.http.routers.django-app.entrypoints=web"
      - "traefik.http.services.django-app.loadbalancer.server.port=8000"
      
    networks:
      - shared-networks
    volumes:
      - ./static:/app/static
      - ./media:/app/media
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  shared-networks:
    external: true
```

### settings.py (Django)
```python
import os

# Database
DATABASES = {
    'default': {
        'ENGINE': os.getenv('DB_ENGINE', 'django.db.backends.postgresql'),
        'NAME': os.getenv('DB_NAME', 'django_app'),
        'USER': os.getenv('DB_USER', 'postgres'),
        'PASSWORD': os.getenv('DB_PASSWORD', 'postgres123'),
        'HOST': os.getenv('DB_HOST', 'postgres'),
        'PORT': os.getenv('DB_PORT', '5432'),
    }
}

# Redis Cache
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.getenv('REDIS_URL', 'redis://:redis123@redis:6379/1'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# Session storage
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'default'
```

## 🟢 Node.js/Express Application

### docker-compose.yml
```yaml
version: '3.8'

services:
  node-app:
    image: node:18-alpine
    container_name: node-app-container
    working_dir: /app
    volumes:
      - ./:/app
      - node_modules:/app/node_modules
    environment:
      # Database Configuration
      DATABASE_URL: postgresql://postgres:postgres123@postgres:5432/node_app
      
      # Redis Configuration
      REDIS_URL: redis://:redis123@redis:6379
      
      # Application Configuration
      NODE_ENV: production
      PORT: 3000
      JWT_SECRET: your-jwt-secret-here
      
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.node-app.rule=Host(`node-app.localhost`)"
      - "traefik.http.routers.node-app.entrypoints=web"
      - "traefik.http.services.node-app.loadbalancer.server.port=3000"
      
    networks:
      - shared-networks
    command: npm start
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  node_modules:

networks:
  shared-networks:
    external: true
```

### app.js (Express)
```javascript
const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();

// PostgreSQL connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// Redis connection
const redisClient = redis.createClient({
  url: process.env.REDIS_URL
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Test database connection
    await pool.query('SELECT 1');
    
    // Test Redis connection
    await redisClient.ping();
    
    res.json({ 
      status: 'healthy', 
      database: 'connected',
      redis: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ 
      status: 'unhealthy', 
      error: error.message 
    });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

## 🔴 Ruby on Rails Application

### docker-compose.yml
```yaml
version: '3.8'

services:
  rails-app:
    build: .
    container_name: rails-app-container
    environment:
      # Database Configuration
      DATABASE_URL: postgresql://postgres:postgres123@postgres:5432/rails_app
      
      # Redis Configuration
      REDIS_URL: redis://:redis123@redis:6379/0
      
      # Rails Configuration
      RAILS_ENV: production
      SECRET_KEY_BASE: your-secret-key-base-here
      
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.rails-app.rule=Host(`rails-app.localhost`)"
      - "traefik.http.routers.rails-app.entrypoints=web"
      - "traefik.http.services.rails-app.loadbalancer.server.port=3000"
      
    networks:
      - shared-networks
    volumes:
      - ./public:/app/public
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  shared-networks:
    external: true
```

### config/database.yml
```yaml
production:
  adapter: postgresql
  url: <%= ENV['DATABASE_URL'] %>
  pool: 5
  timeout: 5000
```

### config/cable.yml
```yaml
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>
  channel_prefix: myapp_production
```

## 🟡 PHP/Laravel Application

### docker-compose.yml
```yaml
version: '3.8'

services:
  laravel-app:
    image: php:8.1-fpm-alpine
    container_name: laravel-app-container
    working_dir: /var/www
    volumes:
      - ./:/var/www
    environment:
      # Database Configuration
      DB_CONNECTION: pgsql
      DB_HOST: postgres
      DB_PORT: 5432
      DB_DATABASE: laravel_app
      DB_USERNAME: postgres
      DB_PASSWORD: postgres123
      
      # Redis Configuration
      REDIS_HOST: redis
      REDIS_PASSWORD: redis123
      REDIS_PORT: 6379
      
      # Laravel Configuration
      APP_ENV: production
      APP_KEY: base64:your-app-key-here
      APP_URL: http://laravel-app.localhost:8080
      
    networks:
      - shared-networks
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    container_name: laravel-nginx
    volumes:
      - ./:/var/www
      - ./docker/nginx.conf:/etc/nginx/conf.d/default.conf
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.laravel-app.rule=Host(`laravel-app.localhost`)"
      - "traefik.http.routers.laravel-app.entrypoints=web"
      - "traefik.http.services.laravel-app.loadbalancer.server.port=80"
    networks:
      - shared-networks
    depends_on:
      - laravel-app
    restart: unless-stopped

networks:
  shared-networks:
    external: true
```

### .env (Laravel)
```bash
APP_NAME=Laravel
APP_ENV=production
APP_KEY=base64:your-app-key-here
APP_DEBUG=false
APP_URL=http://laravel-app.localhost:8080

DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=laravel_app
DB_USERNAME=postgres
DB_PASSWORD=postgres123

REDIS_HOST=redis
REDIS_PASSWORD=redis123
REDIS_PORT=6379

CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
```

## 🟠 Go Application

### docker-compose.yml
```yaml
version: '3.8'

services:
  go-app:
    build: .
    container_name: go-app-container
    environment:
      # Database Configuration
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: postgres123
      DB_NAME: go_app
      DB_SSLMODE: disable
      
      # Redis Configuration
      REDIS_ADDR: redis:6379
      REDIS_PASSWORD: redis123
      REDIS_DB: 0
      
      # Application Configuration
      PORT: 8080
      GIN_MODE: release
      
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.go-app.rule=Host(`go-app.localhost`)"
      - "traefik.http.routers.go-app.entrypoints=web"
      - "traefik.http.services.go-app.loadbalancer.server.port=8080"
      
    networks:
      - shared-networks
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  shared-networks:
    external: true
```

### main.go
```go
package main

import (
    "database/sql"
    "fmt"
    "log"
    "net/http"
    "os"
    
    "github.com/gin-gonic/gin"
    "github.com/go-redis/redis/v8"
    _ "github.com/lib/pq"
)

func main() {
    // Database connection
    dbURL := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
        os.Getenv("DB_HOST"),
        os.Getenv("DB_PORT"),
        os.Getenv("DB_USER"),
        os.Getenv("DB_PASSWORD"),
        os.Getenv("DB_NAME"),
        os.Getenv("DB_SSLMODE"),
    )
    
    db, err := sql.Open("postgres", dbURL)
    if err != nil {
        log.Fatal("Failed to connect to database:", err)
    }
    defer db.Close()
    
    // Redis connection
    rdb := redis.NewClient(&redis.Options{
        Addr:     os.Getenv("REDIS_ADDR"),
        Password: os.Getenv("REDIS_PASSWORD"),
        DB:       0,
    })
    
    r := gin.Default()
    
    // Health check endpoint
    r.GET("/health", func(c *gin.Context) {
        // Test database
        if err := db.Ping(); err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{
                "status": "unhealthy",
                "error":  "database connection failed",
            })
            return
        }
        
        // Test Redis
        if err := rdb.Ping(c.Request.Context()).Err(); err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{
                "status": "unhealthy",
                "error":  "redis connection failed",
            })
            return
        }
        
        c.JSON(http.StatusOK, gin.H{
            "status":   "healthy",
            "database": "connected",
            "redis":    "connected",
        })
    })
    
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    
    r.Run(":" + port)
}
```

## 🔵 .NET Core Application

### docker-compose.yml
```yaml
version: '3.8'

services:
  dotnet-app:
    build: .
    container_name: dotnet-app-container
    environment:
      # Database Configuration
      ConnectionStrings__DefaultConnection: "Host=postgres;Port=5432;Database=dotnet_app;Username=postgres;Password=postgres123"
      
      # Redis Configuration
      ConnectionStrings__Redis: "redis:6379,password=redis123"
      
      # Application Configuration
      ASPNETCORE_ENVIRONMENT: Production
      ASPNETCORE_URLS: http://+:80
      
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dotnet-app.rule=Host(`dotnet-app.localhost`)"
      - "traefik.http.routers.dotnet-app.entrypoints=web"
      - "traefik.http.services.dotnet-app.loadbalancer.server.port=80"
      
    networks:
      - shared-networks
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  shared-networks:
    external: true
```

### appsettings.Production.json
```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=postgres;Port=5432;Database=dotnet_app;Username=postgres;Password=postgres123",
    "Redis": "redis:6379,password=redis123"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

## 🐘 WordPress with Custom Theme

### docker-compose.yml
```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: wordpress-container
    environment:
      # MySQL Configuration
      WORDPRESS_DB_HOST: mysql
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: mysql123
      WORDPRESS_DB_NAME: wordpress_site
      
      # WordPress Configuration
      WORDPRESS_TABLE_PREFIX: wp_
      WORDPRESS_DEBUG: 0
      
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.wordpress.rule=Host(`wordpress.localhost`)"
      - "traefik.http.routers.wordpress.entrypoints=web"
      - "traefik.http.services.wordpress.loadbalancer.server.port=80"
      
    networks:
      - shared-networks
    volumes:
      - ./wp-content:/var/www/html/wp-content
      - ./uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
    restart: unless-stopped
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/wp-admin/install.php"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  shared-networks:
    external: true
```

## 🔄 Multi-Service Application (Frontend + Backend + Worker)

### docker-compose.yml
```yaml
version: '3.8'

services:
  # Frontend (React/Vue/Angular)
  frontend:
    build: ./frontend
    container_name: frontend-container
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.frontend.entrypoints=web"
      - "traefik.http.services.frontend.loadbalancer.server.port=80"
    networks:
      - shared-networks
    restart: unless-stopped

  # Backend API
  backend:
    build: ./backend
    container_name: backend-container
    environment:
      DATABASE_URL: postgresql://postgres:postgres123@postgres:5432/myapp_backend
      REDIS_URL: redis://:redis123@redis:6379
      JWT_SECRET: your-jwt-secret
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.backend.rule=Host(`myapp.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.backend.entrypoints=web"
      - "traefik.http.services.backend.loadbalancer.server.port=3000"
    networks:
      - shared-networks
    restart: unless-stopped

  # Background Worker
  worker:
    build: ./backend
    container_name: worker-container
    environment:
      DATABASE_URL: postgresql://postgres:postgres123@postgres:5432/myapp_backend
      REDIS_URL: redis://:redis123@redis:6379
    command: ["python", "worker.py"]
    networks:
      - shared-networks
    restart: unless-stopped
    # No Traefik labels - internal service only

networks:
  shared-networks:
    external: true
```

## 📝 Common Patterns

### Environment File Template
```bash
# Database Selection (choose one)
# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
POSTGRES_DB=your_app_name

# MySQL
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=mysql123
MYSQL_DATABASE=your_app_name

# Redis (optional)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis123

# Application
APP_NAME=your_app_name
APP_ENV=production
APP_PORT=3000
```

### Health Check Patterns
```yaml
# HTTP health check
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s
  timeout: 10s
  retries: 3

# Database connection check
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres -h postgres"]
  interval: 30s
  timeout: 10s
  retries: 3

# Custom script check
healthcheck:
  test: ["CMD", "/app/health-check.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
```

---

**💡 Pro Tips:**
- Always include health checks for better monitoring
- Use environment variables for all configuration
- Test database connectivity in your health endpoints
- Use specific image tags instead of `latest` in production
- Include restart policies for automatic recovery