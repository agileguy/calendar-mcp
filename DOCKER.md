# Docker Deployment Guide for Google Calendar MCP Server

This guide covers running the Google Calendar MCP Server in Docker containers.

## Quick Start

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Google Cloud OAuth 2.0 credentials (see main README.md)

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/agileguy/calendar-mcp.git
   cd calendar-mcp
   ```

2. **Create environment file:**
   ```bash
   cp example.env .env
   ```

3. **Edit `.env` with your Google OAuth credentials:**
   ```bash
   nano .env  # or vim, code, etc.
   ```

   Update these values:
   ```env
   GOOGLE_CLIENT_ID='your-actual-client-id'
   GOOGLE_CLIENT_SECRET='your-actual-client-secret'
   TOKEN_FILE_PATH='/app/data/.gcp-saved-tokens.json'
   ```

4. **Create data and logs directories:**
   ```bash
   mkdir -p data logs
   ```

## OAuth Authentication Flow

The Google Calendar API requires OAuth 2.0 authentication. There are two approaches for handling this in containers:

### Option 1: Authenticate Locally First (Recommended)

This is the simplest approach for initial setup.

1. **Run authentication locally first:**
   ```bash
   # Install dependencies locally (optional, in a venv)
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt

   # Run server to trigger OAuth flow
   python run_server.py
   ```

2. **Complete OAuth in browser:**
   - Browser opens automatically to Google OAuth consent screen
   - Log in and grant calendar permissions
   - Token saved to `.gcp-saved-tokens.json` (or path in .env)

3. **Move token to data directory:**
   ```bash
   mv .gcp-saved-tokens.json data/
   ```

4. **Now run in Docker:**
   ```bash
   docker-compose up -d
   ```

### Option 2: Authenticate in Container

For headless servers or CI/CD environments.

1. **Run container with port mapping:**
   ```bash
   docker-compose up
   ```

2. **Monitor logs for OAuth URL:**
   ```bash
   docker-compose logs -f calendar-mcp
   ```

3. **Copy the authorization URL from logs and open in browser**

4. **Complete OAuth flow** - token will be saved to mounted `data/` volume

## Running the Container

### Using Docker Compose (Recommended)

**Start the service:**
```bash
docker-compose up -d
```

**View logs:**
```bash
docker-compose logs -f calendar-mcp
```

**Stop the service:**
```bash
docker-compose down
```

**Rebuild after code changes:**
```bash
docker-compose up -d --build
```

### Using Docker Directly

**Build the image:**
```bash
docker build -t calendar-mcp:latest .
```

**Run the container:**
```bash
docker run -d \
  --name calendar-mcp \
  -p 8000:8000 \
  -p 8080:8080 \
  -v $(pwd)/.env:/app/.env:ro \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  calendar-mcp:latest
```

**Run for MCP stdio mode:**
```bash
docker run -i \
  --name calendar-mcp \
  -v $(pwd)/.env:/app/.env:ro \
  -v $(pwd)/data:/app/data \
  -v $(pwd)/logs:/app/logs \
  calendar-mcp:latest
```

## Integration with Claude Code

To use this containerized MCP server with Claude Code:

### Method 1: Stdio via Docker

Add to your Claude Code MCP configuration:

```bash
claude mcp add --transport stdio google-calendar -- \
  docker run -i --rm \
  -v /home/dan/calendar-mcp/.env:/app/.env:ro \
  -v /home/dan/calendar-mcp/data:/app/data \
  -v /home/dan/calendar-mcp/logs:/app/logs \
  calendar-mcp:latest
```

### Method 2: HTTP Server

1. **Run container in HTTP mode:**
   ```bash
   docker-compose up -d
   ```

2. **Configure Claude Code to use HTTP transport:**
   ```bash
   claude mcp add --transport http google-calendar http://localhost:8000
   ```

### Verify Installation

```bash
# List configured MCP servers
claude mcp list

# Check server details
claude mcp get google-calendar

# Inside Claude Code
/mcp
```

## Volume Mounts Explained

The Docker Compose configuration uses three volume mounts:

### 1. Environment File (`.env`)
```yaml
- ./.env:/app/.env:ro
```
- **Purpose:** Contains OAuth credentials and configuration
- **Mode:** Read-only (`:ro`)
- **Security:** Never commit this file to git

### 2. Data Directory (`data/`)
```yaml
- ./data:/app/data
```
- **Purpose:** Persistent storage for OAuth tokens
- **Contains:** `.gcp-saved-tokens.json`
- **Permissions:** Read/write (tokens need refresh)

### 3. Logs Directory (`logs/`)
```yaml
- ./logs:/app/logs
```
- **Purpose:** Application logs for debugging
- **Contains:** `calendar_mcp.log`
- **Useful for:** Troubleshooting auth and API issues

## Troubleshooting

### Container won't start

**Check logs:**
```bash
docker-compose logs calendar-mcp
```

**Common issues:**
- Missing `.env` file → Create from `example.env`
- Invalid OAuth credentials → Check Google Cloud Console
- Permission errors → Check `data/` and `logs/` directory permissions

### OAuth authentication fails

**Symptoms:**
- "Invalid client" errors
- Redirect URI mismatch

**Solutions:**
1. Verify `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env`
2. Check Google Cloud Console redirect URIs include:
   - `http://localhost:8080/oauth2callback`
3. Ensure ports 8080 is accessible (not blocked by firewall)

### Token refresh fails

**Symptoms:**
- "Token has been expired or revoked"
- "invalid_grant" errors

**Solutions:**
1. Delete old token and re-authenticate:
   ```bash
   rm data/.gcp-saved-tokens.json
   docker-compose restart calendar-mcp
   ```
2. Check token file permissions
3. Verify Google Cloud project is still active

### MCP stdio communication issues

**Symptoms:**
- Claude Code can't connect to server
- "Server not responding" errors

**Solutions:**
1. Ensure `-i` flag used: `docker run -i`
2. Check stdin/stdout aren't redirected
3. Verify logs directory is writable (logging must go to file only in stdio mode)

### Port conflicts

**Symptoms:**
- "Address already in use" errors

**Solutions:**
1. Change ports in `docker-compose.yml`:
   ```yaml
   ports:
     - "8001:8000"  # Use 8001 instead
     - "8081:8080"  # Use 8081 instead
   ```
2. Update `.env` if changing OAuth callback port:
   ```env
   OAUTH_CALLBACK_PORT=8081
   ```
3. Update Google Cloud Console redirect URI to match

## Development Mode

For active development with hot-reload:

1. **Uncomment source volume in `docker-compose.yml`:**
   ```yaml
   volumes:
     - ./src:/app/src:ro
   ```

2. **Enable reload in `.env`:**
   ```env
   RELOAD=true
   ```

3. **Run with compose:**
   ```bash
   docker-compose up
   ```

Changes to Python files will trigger automatic reload.

## Production Deployment

For production environments:

1. **Use specific image tags:**
   ```yaml
   image: calendar-mcp:v1.0.0
   ```

2. **Disable reload:**
   ```env
   RELOAD=false
   ```

3. **Use secrets management:**
   - Don't use `.env` file
   - Use Docker secrets or environment variables
   - Consider vault solutions (HashiCorp Vault, AWS Secrets Manager)

4. **Set resource limits:**
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '0.5'
         memory: 512M
       reservations:
         cpus: '0.25'
         memory: 256M
   ```

5. **Configure logging:**
   ```yaml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

## Security Considerations

1. **OAuth Credentials:**
   - Never commit `.env` to version control
   - Use `.env.example` as template only
   - Rotate credentials periodically

2. **Token Storage:**
   - Tokens stored in `data/` directory
   - Ensure proper file permissions (600)
   - Consider encrypting volume in production

3. **Network Security:**
   - Use reverse proxy (nginx) for HTTPS in production
   - Restrict port exposure
   - Consider using Docker networks for isolation

4. **Container Security:**
   - Runs as non-root user (`mcpuser`)
   - Minimal base image (python:3.11-slim)
   - No unnecessary packages installed

## Backup and Recovery

### Backup OAuth Tokens

```bash
# Backup
tar -czf calendar-mcp-backup-$(date +%Y%m%d).tar.gz data/

# Restore
tar -xzf calendar-mcp-backup-YYYYMMDD.tar.gz
```

### Export Environment

```bash
# Backup .env (encrypted)
gpg -c .env  # Creates .env.gpg

# Restore
gpg .env.gpg  # Creates .env
```

## Monitoring

### Health Checks

Docker Compose includes health checks:

```bash
# Check container health
docker-compose ps

# View health check logs
docker inspect calendar-mcp | jq '.[0].State.Health'
```

### Log Monitoring

```bash
# Tail logs
tail -f logs/calendar_mcp.log

# Search for errors
grep ERROR logs/calendar_mcp.log

# Monitor in real-time
docker-compose logs -f --tail=100 calendar-mcp
```

## Updating

### Update Container

```bash
# Pull latest code
git pull origin main

# Rebuild and restart
docker-compose up -d --build

# Clean up old images
docker image prune -f
```

### Update Dependencies

```bash
# Edit requirements.txt
nano requirements.txt

# Rebuild
docker-compose build --no-cache

# Restart
docker-compose up -d
```

## FAQ

**Q: Can I run multiple calendar accounts?**
A: Yes, but you need separate token files. Use multiple container instances with different data volumes and configurations.

**Q: Does this work on ARM (Apple Silicon, Raspberry Pi)?**
A: Yes, the Python base images support multi-arch. Build on your target platform or use buildx for cross-compilation.

**Q: How do I debug authentication issues?**
A: Check `logs/calendar_mcp.log` for detailed error messages. Enable DEBUG logging by setting `LOG_LEVEL=DEBUG` in `.env`.

**Q: Can I use this with Kubernetes?**
A: Yes, convert the Docker Compose to Kubernetes manifests. Use ConfigMaps for config, Secrets for credentials, and PersistentVolumes for token storage.

## Additional Resources

- [Google Calendar API Documentation](https://developers.google.com/calendar/api/guides/overview)
- [MCP Specification](https://modelcontextprotocol.io)
- [Claude Code MCP Guide](https://code.claude.com/docs/en/mcp.md)
- [Docker Documentation](https://docs.docker.com/)

## Support

For issues with:
- **Calendar MCP Server:** https://github.com/agileguy/calendar-mcp/issues
- **Original Project:** https://github.com/deciduus/calendar-mcp
- **MCP Protocol:** https://github.com/modelcontextprotocol
- **Claude Code:** https://github.com/anthropics/claude-code/issues
