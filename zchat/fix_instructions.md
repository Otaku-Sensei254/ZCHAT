# Fix for Fly.io Machine Restarting Issue

## Problem
Your ZCHAT app was restarting frequently because required environment variables were missing, causing the application to crash during startup.

## Changes Made

### 1. Added Missing Environment Variables (fly.toml)
- DATABASE_URL: PostgreSQL connection string
- SECRET_KEY_BASE: Phoenix session encryption key
- CLOUDINARY_API_KEY: Cloudinary API key
- CLOUDINARY_SECRET: Cloudinary API secret
- CLOUDINARY_CLOUD_NAME: Cloudinary cloud name
- CLOUDINARY_PRESET: Cloudinary upload preset

### 2. Enabled Crash Dumps (rel/env.sh.eex)
- Uncommented ERL_CRASH_DUMP and ERL_CRASH_DUMP_BYTES for better debugging

## Next Steps

### Generate Required Values

1. **Generate SECRET_KEY_BASE:**
```bash
mix phx.gen.secret
```

2. **Set up Cloudinary (if using file uploads):**
- Get API key, secret, cloud name, and upload preset from Cloudinary dashboard
- If not using Cloudinary, you'll need to modify the code to handle missing values

3. **Database URL:**
- The provided URL assumes you have a Fly.io PostgreSQL database named "zchat-db"
- Update with your actual database credentials

### Deploy the Fix

1. **Update environment variables with real values:**
```bash
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set DATABASE_URL=your_actual_database_url
fly secrets set CLOUDINARY_API_KEY=your_api_key
fly secrets set CLOUDINARY_SECRET=your_secret
fly secrets set CLOUDINARY_CLOUD_NAME=your_cloud_name
fly secrets set CLOUDINARY_PRESET=your_preset
```

2. **Deploy the updated configuration:**
```bash
fly deploy
```

3. **Monitor the deployment:**
```bash
fly logs
```

## Alternative: Use Fly Secrets (Recommended)

For better security, move sensitive values to Fly secrets instead of fly.toml:

1. Remove sensitive values from fly.toml [env] section
2. Set them using fly secrets command shown above
3. Keep only non-sensitive values in fly.toml

## Verification

After deployment, check:
- App starts without crashing
- Machines stop restarting
- Logs show successful startup
- Database connectivity works
- File uploads work (if using Cloudinary)

## Troubleshooting

If issues persist:
1. Check logs: `fly logs --machine-id 48e2ddda159558`
2. Verify database connectivity
3. Test Cloudinary configuration
4. Consider increasing memory to 2GB if needed
