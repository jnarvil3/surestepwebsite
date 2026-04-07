FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY styles.css /usr/share/nginx/html/styles.css
COPY 404.html /usr/share/nginx/html/404.html
COPY sitemap.xml /usr/share/nginx/html/sitemap.xml
COPY robots.txt /usr/share/nginx/html/robots.txt
COPY jasper.png /usr/share/nginx/html/jasper.png
COPY og-image.png /usr/share/nginx/html/og-image.png
COPY case-studies/ /usr/share/nginx/html/case-studies/
EXPOSE 80
