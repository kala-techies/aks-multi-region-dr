#!/bin/sh
# Pre-start hook, run by the base image's own entrypoint (which execs nginx
# itself once every /docker-entrypoint.d/*.sh script here has finished) -
# this script must NOT exec nginx itself.
set -eu

: "${FRONTEND_API_BASE_URL:?FRONTEND_API_BASE_URL must be set to the ResilientOps API's public URL}"

envsubst '${FRONTEND_API_BASE_URL}' < /usr/share/nginx/html/config.template.js > /usr/share/nginx/html/config.js
