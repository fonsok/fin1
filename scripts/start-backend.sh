#!/bin/bash

# FIN1 Backend Startup Script
# This script sets up and starts the FIN1 backend services using Docker

set -e

echo "🚀 Starting FIN1 Backend Services..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if .env file exists
if [ ! -f "backend/.env" ]; then
    echo "⚠️  Environment file not found. Creating from template..."
    cp backend/env.example backend/.env
    echo "📝 Please edit backend/.env with your configuration before continuing."
    echo "   You can start the services after configuring the environment variables."
    exit 1
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p backend/parse-server/logs
mkdir -p backend/parse-server/certs
mkdir -p backend/nginx/ssl
mkdir -p backend/mongodb/init
mkdir -p backend/postgres/init

# Check if ports are available
echo "🔍 Checking port availability..."
ports=(80 1337 27017 5432 6379 9000 9001 8080 8081 8082)
for port in "${ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port $port is already in use. Please stop the service using this port."
        echo "   You can check what's using the port with: lsof -i :$port"
        exit 1
    fi
done

# Pull latest images
echo "📥 Pulling latest Docker images..."
docker-compose pull

# Build custom images
echo "🔨 Building custom images..."
docker-compose build

# Start services
echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
services=("parse-server" "mongodb" "redis" "postgres" "minio" "nginx")
for service in "${services[@]}"; do
    if docker-compose ps $service | grep -q "Up"; then
        echo "✅ $service is running"
    else
        echo "❌ $service failed to start"
        echo "   Check logs with: docker-compose logs $service"
    fi
done

# Display service URLs
echo ""
echo "🎉 FIN1 Backend Services are starting up!"
echo ""
echo "📋 Service URLs:"
echo "   Parse Server API:    http://localhost:1337/parse"
echo "   Parse Dashboard:     http://localhost:1337/dashboard"
echo "   Nginx Proxy:         http://localhost"
echo "   MinIO Console:       http://localhost:9001"
echo "   Health Check:        http://localhost/health"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs:           docker-compose logs -f"
echo "   Stop services:       docker-compose down"
echo "   Restart services:    docker-compose restart"
echo "   Check status:        docker-compose ps"
echo ""
echo "📚 For more information, see backend/README.md"

# Wait a bit more for full initialization
echo "⏳ Waiting for full initialization..."
sleep 5

# Test Parse Server health
if curl -f http://localhost:1337/health > /dev/null 2>&1; then
    echo "✅ Parse Server is healthy and ready!"
else
    echo "⚠️  Parse Server may still be initializing. Check logs if issues persist."
fi

echo ""
echo "🎯 Your FIN1 backend is ready for development!"
