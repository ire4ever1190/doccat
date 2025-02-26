FROM ekajake/nim-test:2.0.14-alpine AS builder
WORKDIR /tmp
RUN apk add --no-cache git sqlite-dev
ADD . .
RUN nimble update
RUN nimble install https://github.com/ire4ever1190/doit@#ddef9fef8e2708142d13c16d0d3eb42e7b17960c
RUN git config --global --add safe.directory /tmp
# Install dimscord dependencies so that building docs doesn't fail
RUN nimble install dimscord
RUN doit release

FROM alpine:3.20 AS runner
RUN apk add --no-cache sqlite-dev openssl ca-certificates
COPY --from=builder /tmp/build/doccat ./doccat
COPY --from=builder /tmp/build/docs.db ./docs.db
CMD ["./doccat"]
