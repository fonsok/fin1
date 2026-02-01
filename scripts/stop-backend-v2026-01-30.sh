#!/bin/bash

# FIN1 Backend Shutdown Script
# This script stops and cleans up the FIN1 backend services

set -e

echo "🛑 Stopping FIN1 Backend Services..."

# Navigate to project root
cd "$(dirname "$0")/.."

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found. Are you in the correct directory?"
    exit 1
fi

# Stop all services
echo "🛑 Stopping all services..."
docker-compose down

# Ask if user wants to remove volumes (data)
echo ""
read -p "🗑️  Do you want to remove all data volumes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing data volumes..."
    docker-compose down -v
    echo "⚠️  All data has been removed!"
else
    echo "💾 Data volumes preserved. Services can be restarted with existing data."
fi

# Ask if user wants to remove images
echo ""
read -p "🗑️  Do you want to remove Docker images? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗑️  Removing Docker images..."
    docker-compose down --rmi all
    echo "✅ Docker images removed!"
fi

# Clean up unused containers and networks
echo "🧹 Cleaning up unused Docker resources..."
docker system prune -f

echo ""
echo "✅ FIN1 Backend Services have been stopped and cleaned up!"
echo ""
echo "🔧 To start services again, run:"
echo "   ./scripts/start-backend-v2026-01-30.sh"
echo ""
echo "📚 For more information, see backend/README.md"
