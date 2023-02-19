FROM nimlang/choosenim:latest AS builder
WORKDIR /tmp
RUN apt-get install git sqlite3 -y
RUN choosenim devel
ADD . .
RUN nimble update
RUN nimble install https://github.com/ire4ever1190/doit@#4c65b59
RUN git config --global --add safe.directory /tmp
# Install dimscord dependencies so that building docs doesn't fail
RUN nimble install dimscord
RUN doit release

FROM bitnami/minideb:latest AS runner
RUN apt-get update && apt-get install sqlite3 openssl ca-certificates -y
COPY --from=builder /tmp/build/doccat ./doccat
COPY --from=builder /tmp/build/docs.db ./docs.db
CMD ["./doccat"]
