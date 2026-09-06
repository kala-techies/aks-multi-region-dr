// Generated at container start by docker-entrypoint.sh (envsubst) from this
// template - the same image is used in both regions; only API_BASE_URL
// differs, injected via the FRONTEND_API_BASE_URL env var.
window.APP_CONFIG = {
  API_BASE_URL: "${FRONTEND_API_BASE_URL}",
};
