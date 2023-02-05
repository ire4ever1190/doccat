FROM nimlang/nim:1.6.10-alpine AS builder
ADD . /
RUN nimble update
RUN nimble install https://github.com/ire4ever1190/doit@#HEAD
# For some reason setting the path doesn't work =(
RUN cp ~/.nimble/bin/doit /bin/doit
RUN cp ~/.nimble/bin/nimdeps /bin/nimdeps
# Install dimscord dependencies
RUN nimble install dimscord
RUN doit release

FROM alpine:latest AS runner
COPY --from=builder /bin/doccat ./doccat
COPY --from=builder /docs.db ./docs.db
CMD ["./doccat"]
