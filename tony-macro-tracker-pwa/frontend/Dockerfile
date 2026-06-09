FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY sw.js /usr/share/nginx/html/sw.js
COPY manifest.json /usr/share/nginx/html/manifest.json
COPY 2515263.png /usr/share/nginx/html/icon-192.png
COPY 1047711.png /usr/share/nginx/html/icon-512.png
EXPOSE 80
