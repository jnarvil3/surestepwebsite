FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY styles.css /usr/share/nginx/html/styles.css
COPY 404.html /usr/share/nginx/html/404.html
COPY sitemap.xml /usr/share/nginx/html/sitemap.xml
COPY robots.txt /usr/share/nginx/html/robots.txt
COPY jasper.png /usr/share/nginx/html/jasper.png
COPY og-image.png /usr/share/nginx/html/og-image.png
COPY favicon.ico /usr/share/nginx/html/favicon.ico
COPY favicon.svg /usr/share/nginx/html/favicon.svg
COPY favicon-16x16.png /usr/share/nginx/html/favicon-16x16.png
COPY favicon-32x32.png /usr/share/nginx/html/favicon-32x32.png
COPY apple-touch-icon.png /usr/share/nginx/html/apple-touch-icon.png
COPY privacy-policy.html /usr/share/nginx/html/privacy-policy.html
COPY terms-of-service.html /usr/share/nginx/html/terms-of-service.html
COPY data-deletion.html /usr/share/nginx/html/data-deletion.html
COPY case-studies/ /usr/share/nginx/html/case-studies/
EXPOSE 80
