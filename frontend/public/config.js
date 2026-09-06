// Local-dev default. In the container image this file is generated at
// startup by docker-entrypoint.sh from config.template.js, substituting
// the real API_BASE_URL for this deployment (see frontend/Dockerfile).
window.APP_CONFIG = {
  API_BASE_URL: "http://127.0.0.1:8000",
};
