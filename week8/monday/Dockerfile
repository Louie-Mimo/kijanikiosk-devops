FROM node:18-alpine

WORKDIR /app

# Copy manifests first to preserve npm dependency cache
COPY package.json package-lock.json ./

# Monday baseline intentionally includes dev dependencies
RUN npm ci

# Copy application source after dependencies
COPY . .

RUN npm run build

EXPOSE 3000

# Monday baseline - intentionally replaced on Tuesday
CMD ["npm", "start"]