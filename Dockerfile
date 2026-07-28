FROM alpine:latest

RUN apk add --no-cache curl unzip

RUN curl -L -o /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
 && unzip /tmp/xray.zip -d /usr/local/bin/ \
 && rm /tmp/xray.zip

COPY config.json /etc/xray/config.json

EXPOSE 8080

CMD ["xray", "-config", "/etc/xray/config.json"]
