# Stage 1: Build React app
FROM node:20-alpine AS builder

ARG VITE_IDENTITY_URL
ARG VITE_FLIGHT_URL
ARG VITE_BOOKING_URL
ARG VITE_SEARCH_URL

ENV VITE_IDENTITY_URL=$VITE_IDENTITY_URL
ENV VITE_FLIGHT_URL=$VITE_FLIGHT_URL
ENV VITE_BOOKING_URL=$VITE_BOOKING_URL
ENV VITE_SEARCH_URL=$VITE_SEARCH_URL

WORKDIR /app

COPY package.json ./
COPY package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Serve with NGINX
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

RUN chown -R nginx:nginx /usr/share/nginx/html

EXPOSE 3000

USER nginx

CMD ["nginx", "-g", "daemon off;"]
