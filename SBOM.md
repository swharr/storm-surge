# Software Bill of Materials

## Frontend (React/TypeScript)

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| react | ^18.2.0 | MIT | Core UI library for building component-based interfaces |
| react-dom | ^18.2.0 | MIT | React rendering engine for the browser DOM |
| react-router-dom | ^6.20.0 | MIT | Client-side routing for single-page application navigation |
| @tanstack/react-query | ^5.8.0 | MIT | Async state management and server data caching |
| axios | ^1.6.0 | MIT | HTTP client for API communication with middleware |
| recharts | ^2.8.0 | MIT | Charting library for cost and metrics visualizations |
| date-fns | ^2.30.0 | MIT | Date utility functions for formatting and manipulation |
| react-hot-toast | ^2.4.1 | MIT | Toast notification system for user feedback |
| lucide-react | ^0.294.0 | ISC | Icon library for UI elements |
| clsx | ^2.0.0 | MIT | Utility for conditionally joining CSS class names |
| tailwind-merge | ^2.0.0 | MIT | Merges Tailwind CSS classes without style conflicts |
| @headlessui/react | ^1.7.17 | MIT | Accessible unstyled UI components (modals, dropdowns) |
| framer-motion | ^10.16.0 | MIT | Animation library for UI transitions and effects |
| react-hook-form | ^7.47.0 | MIT | Performant form state management and validation |
| @hookform/resolvers | ^3.3.0 | MIT | Validation resolver integration for react-hook-form |
| zod | ^3.22.0 | MIT | TypeScript-first schema validation for form inputs |
| socket.io-client | ^4.7.0 | MIT | WebSocket client for real-time event streaming |
| @types/react | ^18.2.0 | MIT | TypeScript type definitions for React |
| @types/react-dom | ^18.2.0 | MIT | TypeScript type definitions for React DOM |
| @vitejs/plugin-react | ^4.1.0 | MIT | Vite plugin enabling React fast refresh and JSX |
| vite | ^5.0.0 | MIT | Frontend build tool and development server |
| typescript | ^5.2.0 | Apache-2.0 | Static type checking for JavaScript |
| tailwindcss | ^3.3.0 | MIT | Utility-first CSS framework for styling |
| autoprefixer | ^10.4.0 | MIT | PostCSS plugin to add vendor prefixes automatically |
| postcss | ^8.4.0 | MIT | CSS transformation pipeline used by Tailwind |
| eslint | ^8.53.0 | MIT | JavaScript/TypeScript linter for code quality |
| @typescript-eslint/eslint-plugin | ^6.0.0 | MIT | ESLint rules for TypeScript-specific patterns |
| @typescript-eslint/parser | ^6.0.0 | BSD-2-Clause | ESLint parser for TypeScript syntax |
| eslint-plugin-react-hooks | ^4.6.0 | MIT | ESLint rules enforcing React Hooks best practices |
| eslint-plugin-react-refresh | ^0.4.0 | MIT | ESLint rules for React Refresh compatibility |
| vitest | ^0.34.0 | MIT | Unit testing framework compatible with Vite |
| @testing-library/react | ^13.4.0 | MIT | React component testing utilities |
| @testing-library/jest-dom | ^6.0.0 | MIT | Custom DOM matchers for test assertions |
| jsdom | ^22.1.0 | MIT | Browser DOM simulation for headless testing |

## Middleware (Flask/Python)

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| flask | 2.3.3 | BSD-3-Clause | Core web framework for the middleware API |
| gunicorn | 21.2.0 | MIT | Production WSGI HTTP server for Flask |
| requests | 2.31.0 | Apache-2.0 | HTTP client for Spot Ocean API communication |
| PyJWT | 2.8.0 | MIT | JWT token encoding/decoding for authentication |
| pyyaml | 6.0.1 | MIT | YAML parsing for configuration files |
| flask-socketio | 5.3.6 | MIT | WebSocket support for real-time event streaming |
| python-socketio | 5.8.0 | MIT | Socket.IO protocol implementation for Python |
| flask-cors | 4.0.0 | MIT | Cross-origin request handling for frontend access |
| bcrypt | 4.0.1 | Apache-2.0 | Password hashing for secure credential storage |
| Flask-Limiter | 3.7.0 | MIT | API rate limiting to prevent abuse |

### Optional Provider SDKs

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| launchdarkly-server-sdk | 8.2.1 | Apache-2.0 | LaunchDarkly feature flag evaluation (optional) |
| statsig | 1.20.0 | ISC | Statsig feature flag evaluation (optional) |

## FinOps Controller (Python)

| Package | Version | License | Purpose |
|---------|---------|---------|---------|
| launchdarkly-server-sdk | 8.2.1 | Apache-2.0 | Feature flag evaluation for cost optimization decisions |
| requests | 2.31.0 | Apache-2.0 | HTTP client for Spot Ocean API calls |
| schedule | 1.2.0 | MIT | Lightweight job scheduler for time-based scaling |
| pytz | 2023.3 | MIT | Timezone handling for business-hours scheduling |
| python-dotenv | 1.0.0 | BSD-3-Clause | Environment variable loading from .env files |
| pytest | 7.4.3 | MIT | Unit testing framework (dev dependency) |
| pytest-mock | 3.12.0 | MIT | Mocking utilities for pytest (dev dependency) |

## Runtime Services

| Service | Provider | Purpose |
|---------|----------|---------|
| Spot Ocean | NetApp (Spot by NetApp) | Kubernetes cluster auto-scaling and cost optimization |
| LaunchDarkly | LaunchDarkly | Feature flag management and evaluation (optional provider) |
| Statsig | Statsig | Feature flag management and evaluation (optional provider) |
| GKE | Google Cloud | Managed Kubernetes cluster hosting |
| EKS | AWS | Managed Kubernetes cluster hosting |
| AKS | Microsoft Azure | Managed Kubernetes cluster hosting |

Last updated: 2026-03-19
