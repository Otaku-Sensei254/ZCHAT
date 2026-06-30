#!/bin/bash

# Neon Database Setup Script for ZChat
echo "=== ZChat Neon Database Setup ==="
echo ""

# Check if DATABASE_URL is already set
if [ -z "$DATABASE_URL" ]; then
    echo "Please set your DATABASE_URL first:"
    echo "export DATABASE_URL=\"postgresql://[username]:[password]@[neon-host]/[database]?sslmode=require\""
    echo ""
    echo "You can get your connection string from your Neon dashboard:"
    echo "1. Go to your Neon dashboard"
    echo "2. Select your database"
    echo "3. Click 'Connection string'"
    echo "4. Copy the connection string"
    echo ""
    exit 1
fi

echo "DATABASE_URL is set: $DATABASE_URL"
echo ""

# Run migrations
echo "Running migrations on Neon PostgreSQL..."
mix ecto.migrate

if [ $? -eq 0 ]; then
    echo ""
    echo "=== SUCCESS ==="
    echo "Migrations completed successfully!"
    echo ""
    echo "Your ZChat database is now ready on Neon PostgreSQL."
    echo "You can now deploy to Gitalixir."
else
    echo ""
    echo "=== ERROR ==="
    echo "Migration failed. Please check your DATABASE_URL and try again."
fi
