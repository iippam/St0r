#!/bin/bash
set -e

echo "🐳 Building St0r Docker images..."
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found!"
    echo "Creating .env from .env.example..."
    cp .env.example .env
    echo "✏️  Please edit .env with your UrBackup configuration"
    echo ""
fi

# Build backend
echo "📦 Building backend..."
docker build -f backend/Dockerfile -t st0r-backend:latest backend/

# Build frontend
echo "🎨 Building frontend..."
docker build -f frontend/Dockerfile -t st0r-frontend:latest frontend/

echo ""
echo "✅ Images built successfully!"
echo ""
echo "Starting containers with docker-compose..."
docker-compose up -d

echo ""
echo "🚀 St0r is starting up..."
echo "   Frontend:  http://localhost"
echo "   Backend:   http://localhost:3000"
echo "   Database:  localhost:3306"
echo ""
echo "Waiting for services to be ready (30 seconds)..."
sleep 30

echo ""
echo "✨ Services Status:"
docker-compose ps

echo ""
echo "📋 Useful commands:"
echo "   View logs:     docker-compose logs -f"
echo "   Stop services: docker-compose down"
echo "   Remove data:   docker-compose down -v"
echo ""
echo "🔐 Default Credentials:"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
