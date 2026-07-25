# Backend-only image. The repo root is an Expo app; Railway must build and run
# server/ — building from the root package.json launches Metro instead of the
# API and takes production down.
FROM node:20-slim

# better-sqlite3 falls back to node-gyp when no prebuilt binary matches.
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev

COPY server/ ./

ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "index.js"]
