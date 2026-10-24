const backend = 'http://localhost:8180';

const isBrowserNavigation = (req) =>
  req.method === 'GET' && (req.headers.accept ?? '').includes('text/html');

const toBackend = (options = {}) => ({
  target: backend,
  secure: false,
  changeOrigin: false,
  ...options,
});

const spaFallback = (req) => (isBrowserNavigation(req) ? '/index.html' : undefined);

export default {
  '/api': toBackend(),
  '/sanctum': toBackend(),
  '/docs': toBackend(),
  '/login': toBackend({ bypass: spaFallback }),
  '/logout': toBackend(),
  '/two-factor-challenge': toBackend({ bypass: spaFallback }),
  '/user': toBackend(),
};
