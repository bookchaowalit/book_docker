# Docker Applications

This directory contains Docker Compose configurations for various application services. All applications are integrated with Traefik for reverse proxy and SSL termination.

## Available Applications

### Content Management & Documentation

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **WordPress** | http://wordpress.localhost | Popular CMS and blogging platform | MySQL |
| **Ghost** | http://ghost.localhost | Modern publishing platform for blogs | MySQL |
| **BookStack** | http://bookstack.localhost | Self-hosted wiki and documentation platform | MySQL |

### Business & Productivity

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **NocoDB** | http://nocodb.localhost | Airtable alternative - turns databases into smart spreadsheets | MySQL |
| **Baserow** | http://baserow.localhost | No-code database and Airtable alternative | PostgreSQL |
| **N8N** | http://n8n.localhost | Workflow automation tool (Zapier alternative) | PostgreSQL |
| **Twenty** | http://twenty.localhost | Modern CRM platform | PostgreSQL |
| **Vikunja** | http://vikunja.localhost | Task management and team collaboration | PostgreSQL |
| **Metabase** | http://metabase.localhost | Business intelligence and analytics platform | PostgreSQL |

### Communication & Collaboration

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **Rocket.Chat** | http://rocketchat.localhost | Team communication and chat platform | MongoDB |

### Development & Data Science

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **VS Code Server** | http://code-server.localhost | Web-based VS Code IDE | None |
| **JupyterHub** | http://jupyterhub.localhost | Multi-user Jupyter notebook environment | PostgreSQL |
| **ComfyUI** | http://comfyui.localhost | Stable Diffusion GUI | None |
| **OpenBB** | http://openbb.localhost | Financial data analysis platform | None |

### Cloud Storage & File Management

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **Nextcloud** | http://nextcloud.localhost | Self-hosted cloud storage and collaboration | PostgreSQL |

### AI & Language Models

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **Open WebUI** | http://open-webui.localhost | Web UI for LLM interactions | None |
| **LiteLLM** | http://litellm.localhost | Unified API for 100+ LLMs | None |

### Analytics & Backend Services

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **Plausible** | http://plausible.localhost | Privacy-focused web analytics | PostgreSQL, ClickHouse |
| **PocketBase** | http://pocketbase.localhost | Backend as a Service with real-time database | None |

### Social Media & Marketing

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **Mixpost** | http://mixpost.localhost | Social media management platform | MySQL |

### Security & Compliance

| Service | URL | Description | Dependencies |
|---------|-----|-------------|--------------|
| **NCA Toolkit** | http://nca-toolkit.localhost | Network security and compliance tools | None |

## Quick Start

### Start All Applications
```bash
cd /home/bookchaowalit/book/book_docker/docker
./docker-compose-manager.sh up applications
```

### Start Specific Application
```bash
./docker-compose-manager.sh up nextcloud
./docker-compose-manager.sh up rocketchat
./docker-compose-manager.sh up metabase
```

### Check Application Status
```bash
./docker-compose-manager.sh status
```

### View Application Logs
```bash
./docker-compose-manager.sh logs nextcloud
```

## Prerequisites

Before starting applications, ensure you have the required infrastructure and database services running:

### Essential Infrastructure
```bash
./docker-compose-manager.sh up infrastructure
```

### Database Services
```bash
./docker-compose-manager.sh up databases
```

### Monitoring (Optional)
```bash
./docker-compose-manager.sh up monitoring
```

## Configuration

Each application has its own `.env` file with configurable parameters:

- **Database connections**: Most applications connect to shared database services
- **Admin credentials**: Default admin usernames and passwords
- **Email settings**: SMTP configuration for notifications
- **External integrations**: API keys and service configurations

## Networking

All applications use the shared Docker network `shared-networks` and are accessible through:

- **Local development**: `http://[service].localhost`
- **Production**: Configure your domain in Traefik settings

## Storage

Applications use named Docker volumes for data persistence:

- Application data is stored in service-specific volumes
- Configuration files are mounted from local directories
- Backup strategies are implemented through the backup service

## Security Notes

1. **Change default passwords** in `.env` files before production use
2. **Configure SSL certificates** through Traefik for production
3. **Review network access** and firewall rules
4. **Enable authentication** where available
5. **Regular backups** of application data and configurations

## Troubleshooting

### Common Issues

1. **Port conflicts**: Use `./docker-compose-manager.sh fix-ports` to resolve
2. **Database connection errors**: Ensure database services are running first
3. **Memory issues**: Some applications require significant RAM (JupyterHub, ComfyUI)
4. **Storage permissions**: Check Docker volume permissions

### Service Dependencies

Start services in this order to avoid dependency issues:

1. Infrastructure services (Traefik, Consul)
2. Database services (PostgreSQL, MySQL, MongoDB, Redis)
3. Application services
4. Monitoring services

### Health Checks

All applications include health checks. Monitor service health with:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Support

- Check individual service documentation in their respective folders
- Review Docker Compose logs for troubleshooting
- Consult the main project documentation in `/docs`
