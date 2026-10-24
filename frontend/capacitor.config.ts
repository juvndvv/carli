import type { CapacitorConfig } from '@capacitor/cli';

const serverUrl = process.env['CAP_SERVER_URL'] ?? 'http://192.168.0.20:8180';

const config: CapacitorConfig = {
  appId: 'dev.jotade.personal',
  appName: 'carli',
  webDir: 'dist/frontend/browser',
  server: {
    url: serverUrl,
    cleartext: serverUrl.startsWith('http://'),
  },
  ios: {
    contentInset: 'never',
  },
};

export default config;
