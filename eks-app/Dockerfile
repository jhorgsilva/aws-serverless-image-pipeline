# eks-app/Dockerfile - Optimized for size < 200MB
FROM node:18-alpine

# Install only production dependencies and clean cache
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production && \
    npm cache clean --force && \
    rm -rf /tmp/* && \
    rm -rf /root/.npm

COPY index.js ./

# Run as non-root user for security
USER node

CMD ["node", "index.js"]