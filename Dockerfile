# The official go2rtc image bundles go2rtc + ffmpeg and reads /config/go2rtc.yaml
# via its default entrypoint. That's all we need — no custom entrypoint.
FROM alexxit/go2rtc:latest

COPY go2rtc.yaml /config/go2rtc.yaml

EXPOSE 1984 8555
