#!/bin/sh
set -e

# Replace environment variables in nginx config if needed
# This allows for runtime configuration of backend URLs

# Start nginx
exec "$@"
