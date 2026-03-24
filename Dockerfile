FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY jasper.png /usr/share/nginx/html/jasper.png
EXPOSE 80
