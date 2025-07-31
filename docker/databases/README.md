# 🗄️ Database Services

This directory contains all database services organized by type. Each database service is containerized with Docker Compose and configured for development/testing.

## 📋 Available Databases

### Relational Databases
- **PostgreSQL** (`postgres`) - Main relational database with pgvector extension
- **MySQL** (`mysql`) - Popular open-source database
- **MariaDB** (`mariadb`) - MySQL-compatible database
- **SQLite** (`sqlite`) - Lightweight file-based database with web interface

### NoSQL Databases
- **MongoDB** (`mongodb`) - Document-oriented database
- **CouchDB** (`couchdb`) - Document database with web interface
- **Cassandra** (`cassandra`) - Distributed wide-column database

### Graph Databases
- **Neo4j** (`neo4j`) - Graph database with Cypher query language

### Time-Series Databases
- **InfluxDB** (`influxdb`) - Time-series database for metrics and events

### In-Memory Databases
- **Redis** (`redis`) - In-memory data structure store and cache

## 🚀 Quick Start

### Start All Databases
```bash
./docker-manager.sh category databases up
```

### Start Specific Database
```bash
./docker-manager.sh up postgres    # Start PostgreSQL
./docker-manager.sh up redis       # Start Redis
./docker-manager.sh up mongodb     # Start MongoDB
```

### Stop All Databases
```bash
./docker-manager.sh category databases down
```

## 🌐 Database Access

### Web Interfaces
- **Neo4j Browser**: http://neo4j.localhost (neo4j/neo4j123)
- **CouchDB Fauxton**: http://couchdb.localhost (admin/admin123)
- **InfluxDB UI**: http://influxdb.localhost (admin/admin123)
- **SQLite Web**: http://sqlite.localhost

### Direct Database Connections

#### PostgreSQL
- **Host**: localhost
- **Port**: 5432
- **Database**: postgres
- **Username**: postgres
- **Password**: postgres123

#### MySQL
- **Host**: localhost
- **Port**: 3306
- **Database**: app_db
- **Username**: root
- **Password**: your_mysql_root_password_here

#### MariaDB
- **Host**: localhost
- **Port**: 3307
- **Database**: app_db
- **Username**: root
- **Password**: your_mariadb_root_password_here

#### MongoDB
- **Host**: localhost
- **Port**: 27017
- **Database**: app_db
- **Username**: admin
- **Password**: admin123

#### Redis
- **Host**: localhost
- **Port**: 6379
- **Password**: redis123

#### Neo4j
- **HTTP**: localhost:7474
- **Bolt**: localhost:7687
- **Username**: neo4j
- **Password**: neo4j123

#### CouchDB
- **Host**: localhost
- **Port**: 5984
- **Username**: admin
- **Password**: admin123

#### InfluxDB
- **Host**: localhost
- **Port**: 8086
- **Organization**: myorg
- **Bucket**: mybucket
- **Token**: mytoken123

#### Cassandra
- **Host**: localhost
- **Port**: 9042
- **Keyspace**: Create as needed

## 🔧 Database-Specific Features

### PostgreSQL
- **pgvector extension** for vector similarity search
- **Custom image** with AI/ML optimizations
- **Persistent data** with named volumes

### MongoDB
- **Initialization script** creates app user and collections
- **Replica set** ready configuration
- **GridFS** support for file storage

### Redis
- **Persistence** with AOF (Append Only File)
- **Memory optimization** with LRU eviction
- **Password protection** enabled

### Neo4j
- **Graph Data Science** plugin included
- **APOC** procedures available
- **Import directory** mounted for bulk data loading

### InfluxDB
- **v2.x** with modern UI and API
- **Organizations and buckets** preconfigured
- **Flux query language** support

### Cassandra
- **Single node** setup for development
- **Gossip protocol** configured
- **CQL** (Cassandra Query Language) ready

## 📊 Monitoring Integration

All databases include:
- **Health checks** for service monitoring
- **Prometheus metrics** (where supported)
- **Grafana dashboards** available
- **Logging** to central log aggregation

## 🔐 Security Configuration

### Default Credentials (Change for Production!)
- All databases use **development credentials**
- **Environment files** contain configurable passwords
- **Vault integration** available for secret management

### Network Security
- All databases run on **isolated networks**
- **Internal communication** only (except web UIs)
- **Traefik proxy** for secure external access

## 💾 Data Persistence

### Volume Management
- **Named volumes** for data persistence
- **Backup-friendly** volume structure
- **Easy data migration** between environments

### Backup Strategy
```bash
# PostgreSQL backup
docker exec postgres_container pg_dump -U postgres postgres > backup.sql

# MongoDB backup
docker exec mongodb_container mongodump --out /backup

# Redis backup
docker exec redis_container redis-cli --rdb /data/backup.rdb
```

## 🛠️ Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check which service is using a port
docker ps --filter "publish=5432"

# Stop conflicting services
./docker-manager.sh fix-ports
```

#### Database Won't Start
```bash
# Check logs
./docker-manager.sh logs postgres

# Check health status
docker ps --format "table {{.Names}}\\t{{.Status}}"
```

#### Connection Issues
```bash
# Test database connectivity
docker exec -it postgres_container psql -U postgres
docker exec -it mongodb_container mongosh
docker exec -it redis_container redis-cli
```

### Performance Tuning

#### Memory Allocation
- **PostgreSQL**: Adjust `shared_buffers`, `work_mem`
- **MongoDB**: Set `wiredTigerCacheSizeGB`
- **Redis**: Configure `maxmemory` and eviction policy
- **Cassandra**: Tune JVM heap settings

#### Storage Optimization
- Use **SSD storage** for better performance
- **Separate volumes** for data and logs
- **Regular maintenance** (VACUUM, REINDEX, etc.)

## 📚 Additional Resources

### Documentation Links
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [MongoDB Manual](https://docs.mongodb.com/)
- [Redis Documentation](https://redis.io/documentation)
- [Neo4j Documentation](https://neo4j.com/docs/)
- [InfluxDB Documentation](https://docs.influxdata.com/)
- [Cassandra Documentation](https://cassandra.apache.org/doc/)

### Development Tools
- **DBeaver**: Universal database client
- **MongoDB Compass**: MongoDB GUI
- **RedisInsight**: Redis management tool
- **Neo4j Desktop**: Graph database IDE

---

**💡 Pro Tip**: Use `./docker-manager.sh status` to check the health of all database services!
