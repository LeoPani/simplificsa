FROM nginx:alpine

# Remove a config padrão do nginx
RUN rm -f /etc/nginx/conf.d/default.conf

# Copia o site estático
COPY index.html /usr/share/nginx/html/index.html

# Cria o template de config do nginx.
# Usa 'EOF' (com aspas) para que ${PORT} e $uri NÃO sejam expandidos pelo shell
# durante o build — a substituição de ${PORT} acontece só em runtime via envsubst.
RUN cat > /etc/nginx/conf.d/app.conf.template << 'EOF'
server {
    listen ${PORT};
    root /usr/share/nginx/html;
    index index.html;
    location / {
        try_files $uri /index.html;
    }
}
EOF

# Em runtime: substitui $PORT no template e inicia o nginx
CMD ["/bin/sh", "-c", "envsubst '${PORT}' < /etc/nginx/conf.d/app.conf.template > /etc/nginx/conf.d/app.conf && nginx -g 'daemon off;'"]
