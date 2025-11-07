# Coffee Project - Docker Setup

## Quick Start

```bash
# Start coffee app + database
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop everything
docker-compose down
```

## What's Running

- **Coffee App**: http://localhost:3000
- **PostgreSQL Database**: localhost:5432
  - User: postgres
  - Password: postgres
  - Database: coffee_dev

## Test the App

```bash
# Get coffees
curl http://localhost:3000/coffees

# Place order
curl -X POST http://localhost:3000/order \
  -H "Content-Type: application/json" \
  -d '{"coffeeId": 1, "quantity": 2}'
```

## Common Commands

```bash
# Rebuild after code changes
docker-compose up -d --build

# View app logs
docker-compose logs -f app

# View database logs
docker-compose logs -f db

# Access database
docker-compose exec db psql -U postgres coffee_dev

# Stop and remove everything (including data)
docker-compose down -v
```

## Deploy on VCL Machine

```bash
# 1. Ensure Docker is installed
docker --version

# 2. Clone repo and start services
git clone <your-repo-url>
cd devops-project/coffee_project
docker-compose up -d

# 3. Verify
curl http://localhost:3000/coffees
```

That's it!
