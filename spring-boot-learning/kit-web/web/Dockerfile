# The front end image: build with Node, serve the static files with nginx (non-root, port 8080), proxy /api.
#   docker build -t __APP__-web .        docker run -p 8081:8080 -e API_UPSTREAM=http://host.docker.internal:8080 __APP__-web
FROM node:22.23.3-alpine3.24 AS build
WORKDIR /web
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build

FROM nginxinc/nginx-unprivileged:1.30.4-alpine3.24
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY nginx/security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY --from=build /web/dist /usr/share/nginx/html
ENV API_UPSTREAM=http://app:8080
EXPOSE 8080
