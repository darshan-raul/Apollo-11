FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o /notification-service

FROM alpine:3.19

RUN apk --no-cache add ca-certificates \
    && addgroup -S apollo \
    && adduser -S -G apollo apollo

WORKDIR /app

COPY --from=builder --chown=apollo:apollo /notification-service /app/notification-service

EXPOSE 8084

USER apollo

CMD ["/app/notification-service"]
