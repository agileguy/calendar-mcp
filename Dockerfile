# Multi-stage build for Google Calendar MCP Server
# Stage 1: Builder
FROM python:3.11-slim as builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash mcpuser

# Set working directory
WORKDIR /app

# Copy Python dependencies from builder
COPY --from=builder /root/.local /home/mcpuser/.local

# Copy application code
COPY --chown=mcpuser:mcpuser . .

# Ensure the Python packages are in PATH
ENV PATH=/home/mcpuser/.local/bin:$PATH

# Create directory for tokens and logs with proper permissions
RUN mkdir -p /app/data /app/logs && \
    chown -R mcpuser:mcpuser /app/data /app/logs

# Switch to non-root user
USER mcpuser

# Expose FastAPI port (for HTTP mode testing)
EXPOSE 8000

# Health check (for HTTP mode)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health', timeout=5)" || exit 1

# Default command runs the server
CMD ["python", "run_server.py"]
