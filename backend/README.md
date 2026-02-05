# FIN1 Backend Services

This directory contains the Docker containerized backend services for the FIN1 project.

## 🏗 Architecture Overview

The backend consists of the following microservices:

- **Parse Server** - Main API and authentication
- **MongoDB** - Primary database for user data and transactions
- **PostgreSQL** - Analytics and reporting database
- **Redis** - Caching and session storage
- **MinIO** - File storage (S3-compatible)
- **Nginx** - Reverse proxy and load balancer
- **Market Data Service** - Real-time trading data
- **Notification Service** - Push notifications
- **Analytics Service** - Data processing and reporting

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available for containers
- Ports 80, 1337, 27017, 5432, 6379, 9000, 9001, 8080-8082 available

### Development Setup

1. **Clone and navigate to the project**
   ```bash
   cd /Users/ra/app/FIN1
   ```

2. **Copy environment variables**
   ```bash
   cp backend/env.example backend/.env
   # Edit backend/.env with your configuration
   ```

3. **Start all services**
   ```bash
   docker-compose up -d
   ```

4. **Verify services are running**
   ```bash
   docker-compose ps
   ```

5. **Check logs**
   ```bash
   docker-compose logs -f parse-server
   ```

### Service URLs

- **Parse Server API**: http://localhost:1337/parse
- **Parse Dashboard**: http://localhost:1337/dashboard
- **Nginx Proxy**: http://localhost
- **MinIO Console**: http://localhost:9001
- **Health Check**: http://localhost/health

## 📁 Directory Structure

```
backend/
├── parse-server/           # Main Parse Server application
│   ├── Dockerfile
│   ├── package.json
│   ├── index.js
│   ├── cloud/             # Cloud functions
│   └── certs/             # SSL certificates
├── market-data/           # Market data service
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
├── notification-service/  # Push notification service
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
├── analytics-service/     # Analytics and reporting
│   ├── Dockerfile
│   ├── package.json
│   └── index.js
├── nginx/                 # Nginx configuration
│   ├── nginx.conf
│   └── ssl/              # SSL certificates
├── mongodb/              # MongoDB initialization
│   └── init/
├── postgres/             # PostgreSQL initialization
│   └── init/
├── docker-compose.yml    # Main orchestration file
├── env.example          # Environment variables template
└── README.md            # This file
```

## 🔧 Development Commands

### Start Services
```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d parse-server

# Start with logs
docker-compose up
```

### Stop Services
```bash
# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Stop specific service
docker-compose stop parse-server
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f parse-server

# Last 100 lines
docker-compose logs --tail=100 parse-server
```

### Execute Commands
```bash
# Access Parse Server container
docker-compose exec parse-server sh

# Run npm commands
docker-compose exec parse-server npm run dev

# Access database
docker-compose exec mongodb mongosh
docker-compose exec postgres psql -U fin1_user -d fin1_analytics
```

### Rebuild Services
```bash
# Rebuild all services
docker-compose build

# Rebuild specific service
docker-compose build parse-server

# Rebuild and restart
docker-compose up -d --build parse-server
```

## 🗄️ Database Management

### MongoDB
- **Connection**: `mongodb://admin:fin1-mongo-password@localhost:27017/fin1`
- **Admin Panel**: Parse Dashboard at http://localhost:1337/dashboard
- **Direct Access**: `docker-compose exec mongodb mongosh`

### PostgreSQL
- **Connection**: `postgresql://fin1_user:fin1-postgres-password@localhost:5432/fin1_analytics`
- **Direct Access**: `docker-compose exec postgres psql -U fin1_user -d fin1_analytics`

### Redis
- **Connection**: `redis://:fin1-redis-password@localhost:6379`
- **Direct Access**: `docker-compose exec redis redis-cli`

## 📊 Monitoring and Health Checks

### Health Endpoints
- Parse Server: http://localhost:1337/health
- Market Data: http://localhost:8080/health
- Notifications: http://localhost:8081/health
- Analytics: http://localhost:8082/health

### Container Status
```bash
# Check all containers
docker-compose ps

# Check resource usage
docker stats

# Check specific container
docker-compose exec parse-server ps aux
```

## 🔒 Security Configuration

### Environment Variables
- Change all default passwords in production
- Use strong JWT secrets
- Enable HTTPS in production
- Configure proper CORS origins

### SSL/TLS
- Place SSL certificates in `backend/nginx/ssl/`
- Update nginx.conf for HTTPS configuration
- Use Let's Encrypt for production certificates

## 🚀 Production Deployment

### Environment Setup
1. Copy `env.example` to `.env`
2. Update all passwords and secrets
3. Set `NODE_ENV=production`
4. Configure production URLs
5. Enable SSL certificates

### Scaling
```bash
# Scale Parse Server
docker-compose up -d --scale parse-server=3

# Scale with load balancer
docker-compose up -d --scale parse-server=3 --scale nginx=2
```

### Backup
```bash
# Backup MongoDB
docker-compose exec mongodb mongodump --out /backup

# Backup PostgreSQL
docker-compose exec postgres pg_dump -U fin1_user fin1_analytics > backup.sql
```

## 🐛 Troubleshooting

### Common Issues

1. **Port conflicts**
   ```bash
   # Check port usage
   lsof -i :1337

   # Stop conflicting services
   sudo lsof -ti:1337 | xargs kill -9
   ```

2. **Container won't start**
   ```bash
   # Check logs
   docker-compose logs parse-server

   # Check container status
   docker-compose ps
   ```

3. **Database connection issues**
   ```bash
   # Check database containers
   docker-compose ps mongodb postgres redis

   # Test connections
   docker-compose exec parse-server ping mongodb
   ```

4. **Permission issues**
   ```bash
   # Fix file permissions
   sudo chown -R $USER:$USER backend/

   # Rebuild containers
   docker-compose build --no-cache
   ```

### Performance Optimization

1. **Increase memory limits**
   ```yaml
   # In docker-compose.yml
   deploy:
     resources:
       limits:
         memory: 2G
   ```

2. **Enable logging rotation**
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

## 📚 API Documentation

### Parse Server API
- **Base URL**: http://localhost:1337/parse
- **Documentation**: http://localhost:1337/api-docs
- **Dashboard**: http://localhost:1337/dashboard

### Market Data API
- **Base URL**: http://localhost:8080
- **WebSocket**: ws://localhost:8080/ws

### Notification API
- **Base URL**: http://localhost:8081

### Analytics API
- **Base URL**: http://localhost:8082

## 🤝 Contributing

1. Make changes to the appropriate service
2. Test locally with `docker-compose up`
3. Update documentation if needed
4. Submit pull request

## 📄 License

This project is proprietary software. All rights reserved.
