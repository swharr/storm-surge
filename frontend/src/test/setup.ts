import '@testing-library/jest-dom'

// Mock environment variables
Object.defineProperty(import.meta, 'env', {
  value: {
    MODE: 'test',
    BASE_URL: '/',
    PROD: false,
    DEV: false,
    SSR: false,
  },
  writable: false,
})