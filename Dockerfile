FROM centos:7
ENV LANG=en_US.UTF-8
COPY ./tengine-2.3.3 /app/download/tengine-2.3.3
RUN yum install -y gcc gcc-c++ automake pcre pcre-devel zlip zlib-devel openssl openssl-devel

WORKDIR /app/download/tengine-2.3.3
RUN /app/download/tengine-2.3.3/configure --prefix=/app/tengine --add-module=/app/download/tengine-2.3.3/modules/echo-nginx-module --add-module=/app/download/tengine-2.3.3/modules/ngx_http_upstream_check_module --with-stream --with-stream_ssl_module
RUN make && make install
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

WORKDIR /app/tengine
RUN mkdir -p /app/tengine/conf/conf.d
RUN mkdir -p /app/tengine/conf/stream.d
RUN mkdir -p /sensorsdata/stdata/nginx/res

EXPOSE 8106
EXPOSE 8108

CMD /app/tengine/sbin/nginx -g "daemon off;"
