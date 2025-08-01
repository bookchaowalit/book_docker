# Centralized Infrastructure Integration Guide

This guide explains how to integrate your applications with our centralized Docker infrastructure, including shared databases, networking, and proxy configuration.

## 🏗️ Overview

Our centralized infrastructure provides shared services that multiple applications can use, eliminating the need for each application to run its own database instances and proxy services.

### Available Shared Services

| Service | Host | Port | Purpose |
|---------|------|------|---------|
| **PostgreSQL** | `postgres` | 5432 | Primary relational database |
| **MySQL** | `mysql` | 3306 | Alternative relational database |
| **Redis** | `redis` | 6379 | Caching and session storage |
| **MongoDB** | `mongodb` | 27017 | Document database |
| **Traefik** | `shared_traefik` | 80/443 | Reverse proxy and load balancer |

## 🌐 Network Configuration

### Required Networks

All applications must connect to our shared Docker network:

```yaml
networks:
  shared-networks:
    external: true
```

### Network Usage

- **shared-networks**: The single network for all service communication and discovery

## 🗄️ Database Integration

### PostgreSQL Integration

For applications using PostgreSQL:

```yaml
# docker-compose.yml
services:
  your-app:
    image: your-app:latest
    environment:
      # Database Configuration
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: your_app_db
      # Alternative formats
      DATABASE_URL: postgresql://postgres:postgres123@postgres:5432/your_app_db
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: postgres123
      DB_NAME: your_app_db
    networks:
      - shared-networks
    depends_on:
      - postgres  # Optional: if you want to ensure database is ready

networks:
  shared-networks:
    external: true
```

### MySQL Integration

For applications using MySQL:

```yaml
services:
  your-app:
    image: your-app:latest
    environment:
      # Database Configuration
      MYSQL_HOST: mysql
      MYSQL_PORT: 3306
      MYSQL_ROOT_PASSWORD: mysql123
      MYSQL_DATABASE: your_app_db
      MYSQL_USER: your_app_user
      MYSQL_PASSWORD: your_app_password
      # Alternative formats
      DATABASE_URL: mysql://your_app_user:your_app_password@mysql:3306/your_app_db
      DB_HOST: mysql
      DB_PORT: 3306
    networks:
      - shared-networks
```

### Redis Integration

For applications using Redis:

```yaml
services:
  your-app:
    image: your-app:latest
    environment:
      # Redis Configuration
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: redis123
      # Alternative formats
      REDIS_URL: redis://:redis123@redis:6379
      CACHE_URL: redis://:redis123@redis:6379
    networks:
      - shared-networks
```

### MongoDB Integration

For applications using MongoDB:

```yaml
services:
  your-app:
    image: your-app:latest
    environment:
      # MongoDB Configuration
      MONGODB_HOST: mongodb
      MONGODB_PORT: 27017
      MONGODB_USERNAME: admin
      MONGODB_PASSWORD: admin123
      MONGODB_DATABASE: your_app_db
      # Alternative formats
      MONGODB_URI: mongodb://admin:admin123@mongodb:27017/your_app_db
      MONGO_URL: mongodb://admin:admin123@mongodb:27017/your_app_db
    networks:
      - shared-networks
```

## 🚦 Traefik Integration (Reverse Proxy)

### Basic Traefik Configuration

To expose your application through our centralized Traefik:

```yaml
services:
  your-app:
    image: your-app:latest
    labels:
      # Enable Traefik
      - "traefik.enable=true"
      # Define the route
      - "traefik.http.routers.your-app.rule=Host(`your-app.localhost`)"
      - "traefik.http.routers.your-app.entrypoints=web"
      # Specify the port your app runs on
      - "traefik.http.services.your-app.loadbalancer.server.port=8080"
    networks:
      - shared-networks
    # Remove direct port mapping - access through Traefik
    # ports:
    #   - "8080:8080"  # Don't expose ports directly
```

### Advanced Traefik Configuration

For more complex routing needs:

```yaml
services:
  your-app:
    image: your-app:latest
    labels:
      - "traefik.enable=true"
      # Multiple domains
      - "traefik.http.routers.your-app.rule=Host(`your-app.localhost`) || Host(`app.localhost`)"
      # Path-based routing
      - "traefik.http.routers.your-app-api.rule=Host(`your-app.localhost`) && PathPrefix(`/api`)"
      # HTTPS redirect
      - "traefik.http.routers.your-app.entrypoints=web,websecure"
      - "traefik.http.routers.your-app.tls=true"
      # Middleware (optional)
      - "traefik.http.routers.your-app.middlewares=auth@file"
      # Service configuration
      - "traefik.http.services.your-app.loadbalancer.server.port=3000"
    networks:
      - shared-networks
```

## 📋 Complete Integration Example

Here's a complete example of a Node.js application integrating with our centralized infrastructure:

```yaml
# docker-compose.yml
version: '3.8'

services:
  my-node-app:
    image: node:18-alpine
    container_name: my-node-app-container
    working_dir: /app
    volumes:
      - ./:/app
      - node_modules:/app/node_modules
    environment:
      # Database Configuration
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: my_node_app
      
      # Redis Configuration
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: redis123
      
      # Application Configuration
      NODE_ENV: production
      PORT: 3000
      
    labels:
      # Traefik Configuration
      - "traefik.enable=true"
      - "traefik.http.routers.my-node-app.rule=Host(`my-node-app.localhost`)"
      - "traefik.http.routers.my-node-app.entrypoints=web"
      - "traefik.http.services.my-node-app.loadbalancer.server.port=3000"
      
    networks:
      - shared-networks
    
    command: npm start
    restart: unless-stopped
    
    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  node_modules:

networks:
  shared-networks:
    external: true
```

## 🔧 Environment File Template

Create a `.env` file for your application:

```bash
# .env file template for centralized infrastructure

# Database Configuration (Choose one)
# PostgreSQL
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
POSTGRES_DB=your_app_name

# MySQL (alternative)
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=mysql123
MYSQL_DATABASE=your_app_name
MYSQL_USER=your_app_user
MYSQL_PASSWORD=your_app_password

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis123

# MongoDB Configuration
MONGODB_HOST=mongodb
MONGODB_PORT=27017
MONGODB_USERNAME=admin
MONGODB_PASSWORD=admin123
MONGODB_DATABASE=your_app_name

# Application Configuration
APP_NAME=your_app_name
APP_PORT=3000
APP_ENV=production

# Traefik Configuration
TRAEFIK_DOMAIN=your-app.localhost
```

## 🚀 Deployment Steps

### 1. Prepare Your Application

1. **Update docker-compose.yml** with centralized infrastructure configuration
2. **Create .env file** with appropriate database connections
3. **Remove direct port mappings** (use Traefik instead)
4. **Add required networks** to your compose file

### 2. Deploy Your Application

```bash
# Ensure centralized infrastructure is running
./docker-manager.sh infra-status

# If not running, start it
./docker-manager.sh infra-start

# Deploy your application
docker-compose up -d

# Check if your app is accessible through Traefik
curl http://your-app.localhost:8080
```

### 3. Verify Integration

```bash
# Check if your app is connected to shared networks
docker network inspect shared-networks

# Check if Traefik can see your service
curl http://localhost:8090/api/rawdata | grep your-app

# Test database connectivity
docker exec your-app-container ping postgres
docker exec your-app-container ping redis
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Application Can't Connect to Database

```bash
# Check if centralized infrastructure is running
./docker-manager.sh infra-status

# Check network connectivity
docker exec your-app-container ping postgres
docker exec your-app-container nslookup postgres
```

#### 2. Traefik Not Routing to Your App

```bash
# Check Traefik dashboard
curl http://localhost:8090/api/rawdata

# Verify labels are correct
docker inspect your-app-container | grep -A 10 Labels

# Check if app is on shared network
docker network inspect shared-networks
```

#### 3. Database Connection Refused

```bash
# Check database status
docker exec shared_postgres pg_isready -U postgres
docker exec shared_mysql mysqladmin ping -h localhost

# Check if database exists
docker exec shared_postgres psql -U postgres -l
```

### Debug Commands

```bash
# Check all running services
./docker-manager.sh status

# View centralized infrastructure logs
./docker-manager.sh infra-status

# Check specific service logs
docker logs shared_postgres
docker logs shared_traefik

# Test network connectivity
docker run --rm --network shared-networks alpine ping postgres
```

## 📊 Monitoring and Health Checks

### Application Health Checks

Add health checks to your applications:

```yaml
services:
  your-app:
    # ... other configuration
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Database Health Monitoring

Monitor database connections in your application:

```javascript
// Node.js example
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.POSTGRES_HOST,
  port: process.env.POSTGRES_PORT,
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (error) {
    res.status(500).json({ status: 'unhealthy', error: error.message });
  }
});
```

## 🔐 Security Best Practices

### 1. Environment Variables

- Never hardcode credentials in docker-compose.yml
- Use .env files for sensitive configuration
- Consider using Docker secrets for production

### 2. Network Security

- Only expose necessary ports through Traefik
- Use internal network communication between services
- Implement proper authentication in your applications

### 3. Database Security

- Create application-specific database users
- Use least-privilege access principles
- Regularly update database passwords

## 📚 Additional Resources

### Useful Links

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
- [MySQL Docker Hub](https://hub.docker.com/_/mysql)
- [Redis Docker Hub](https://hub.docker.com/_/redis)

### Example Applications

Check our repository for example integrations:
- `docker/applications/baserow/` - PostgreSQL integration
- `docker/applications/wordpress/` - MySQL integration
- `docker/applications/nocodb/` - PostgreSQL with Traefik

### Support

For questions or issues:
1. Check the troubleshooting section above
2. Review logs: `./docker-manager.sh logs <service-name>`
3. Check infrastructure status: `./docker-manager.sh status`

---

**💡 Pro Tip**: Always test your integration in development before deploying to production. Use `./docker-manager.sh disk-usage` to monitor resource consumption of your applications.