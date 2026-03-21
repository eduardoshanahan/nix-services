ARG D2_IMAGE_REPOSITORY=terrastruct/d2
ARG D2_IMAGE_TAG=v0.7.1

FROM golang:1.24-alpine AS builder
WORKDIR /src

COPY app/go.mod app/go.sum ./
RUN go mod download

COPY app/main.go ./main.go
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$(go env GOARCH) go build -trimpath -ldflags='-s -w' -o /out/d2-web ./main.go

FROM ${D2_IMAGE_REPOSITORY}:${D2_IMAGE_TAG}
WORKDIR /app
COPY --from=builder /out/d2-web /usr/local/bin/d2-web
ENTRYPOINT ["/usr/local/bin/d2-web"]
