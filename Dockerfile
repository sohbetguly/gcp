FROM teddysun/xray:latest

COPY config.json /etc/xray/config.json

EXPOSE 8080

CMD ["xray", "run", "-c", "/etc/xray/config.json"]
