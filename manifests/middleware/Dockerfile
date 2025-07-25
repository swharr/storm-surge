FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements files
COPY requirements*.txt ./

# Install base dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install provider-specific dependencies based on build argument
ARG FEATURE_FLAG_PROVIDER=launchdarkly
RUN if [ "$FEATURE_FLAG_PROVIDER" = "launchdarkly" ]; then \
        pip install --no-cache-dir -r requirements-launchdarkly.txt; \
    elif [ "$FEATURE_FLAG_PROVIDER" = "statsig" ]; then \
        pip install --no-cache-dir -r requirements-statsig.txt; \
    fi

# Copy application code
COPY *.py ./

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start application
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--timeout", "60", "main:app"]
