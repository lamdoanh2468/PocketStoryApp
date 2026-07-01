# syntax=docker/dockerfile:1

FROM node:22-alpine AS app

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# Install dependencies first to improve Docker layer caching.
# This supports npm projects with or without package-lock.json.
COPY package*.json ./
RUN if [ -f package-lock.json ]; then \
      npm ci; \
    else \
      npm install; \
    fi

# Copy the application source.
COPY . .

# Build only when a build script exists, then remove dev dependencies.
RUN npm run build --if-present && npm prune --omit=dev

EXPOSE 3000

CMD ["npm", "start"]
