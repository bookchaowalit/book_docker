# Quick Integration Reference Card

## 🚀 Essential Configuration

### Networks (Required)
```yaml
networks:
  shared-networks:
    external: true
```

### Database Connections

| Database | Host | Port | User | Password |
|----------|------|------|------|----------|
| PostgreSQL | `postgres` | 5432 | `postgres` | `postgres123` |
| MySQL | `mysql` | 3306 | `root` | `mysql123` |
| Redis | `redis` | 6379 | - | `redis123` |
| MongoDB | `mongodb` | 27017 | `admin` | `admin123` |

### Traefik Labels (Web Access)
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.YOUR_APP.rule=Host(`YOUR_APP.localhost`)"
  - "traefik.http.routers.YOUR_APP.entrypoints=web"
  - "traefik.http.services.YOUR_APP.loadbalancer.server.port=YOUR_PORT"
```

## 📋 Minimal docker-compose.yml Template

```yaml
version: '3.8'

services:
  your-app:
    image: your-app:latest
    container_name: your-app-container
    environment:
      # PostgreSQL
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
      POSTGRES_DB: your_app_db
      
      # Redis (optional)
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_PASSWORD: redis123
      
    labels:
      # Traefik
      - "traefik.enable=true"
      - "traefik.http.routers.your-app.rule=Host(`your-app.localhost`)"
      - "traefik.http.routers.your-app.entrypoints=web"
      - "traefik.http.services.your-app.loadbalancer.server.port=3000"
      
    networks:
      - shared-networks
    restart: unless-stopped

networks:
  shared-networks:
    external: true
```

## 🔧 Common Environment Variables

### PostgreSQL Apps
```bash
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres123
POSTGRES_DB=your_app_name
DATABASE_URL=postgresql://postgres:postgres123@postgres:5432/your_app_name
```

### MySQL Apps
```bash
MYSQL_HOST=mysql
MYSQL_PORT=3306
MYSQL_ROOT_PASSWORD=mysql123
MYSQL_DATABASE=your_app_name
DATABASE_URL=mysql://root:mysql123@mysql:3306/your_app_name
```

### Redis Apps
```bash
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=redis123
REDIS_URL=redis://:redis123@redis:6379
```

## 🌐 Access URLs

After deployment, your app will be available at:
- **Local**: `http://your-app.localhost:8080`
- **Traefik Dashboard**: `http://localhost:8090`

## ⚡ Quick Commands

```bash
# Check infrastructure status
./docker-manager.sh infra-status

# Start infrastructure if needed
./docker-manager.sh infra-start

# Deploy your app
docker-compose up -d

# Check if accessible
curl http://your-app.localhost:8080

# View logs
docker-compose logs -f

# Test database connection
docker exec your-app-container ping postgres
```

## 🚨 Common Mistakes to Avoid

❌ **Don't expose ports directly**
```yaml
ports:
  - "3000:3000"  # Remove this - use Traefik instead
```

❌ **Don't use localhost for database host**
```yaml
environment:
  DB_HOST: localhost  # Wrong - use 'postgres' instead
```

❌ **Don't forget external networks**
```yaml
networks:
  my-network:  # Wrong - use shared-networks instead
```

✅ **Do use service names for internal communication**
```yaml
environment:
  DB_HOST: postgres  # Correct
  REDIS_HOST: redis  # Correct
```

## 🔍 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Can't connect to database | Check if infrastructure is running: `./docker-manager.sh infra-status` |
| App not accessible via browser | Verify Traefik labels and network configuration |
| "Network not found" error | Ensure centralized infrastructure is started first |
| Database connection refused | Check database credentials and host names |

## 📞 Need Help?

1. **Check status**: `./docker-manager.sh status`
2. **View logs**: `docker-compose logs your-service`
3. **Test connectivity**: `docker exec your-app ping postgres`
4. **Check Traefik**: `curl http://localhost:8090/api/rawdata`

---
**💡 Tip**: Always start with the minimal template above and add complexity as needed!