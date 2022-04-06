# 简易神策数据接收服务搭建

神策的数据接收服务前端使用的是定制版的 Nginx，通过 access_log 来完成埋点数据的落盘。

我们也可以直接使用 Nginx 搭建一个简易的接收服务，并使用和神策标准一致的 log formatter 对 Nginx 进行配置，以便后续能无缝将数据迁移至标准神策服务。

## 安装 Tengine
我们以 CentOS 环境为例来进行安装配置。

### 安装必要的依赖，为编译 module 作准备
```bash
yum install -y gcc gcc-c++ automake pcre pcre-devel zlip zlib-devel openssl openssl-devel
```

### 从官网下载 Tengine 的源码包
```bash
wget https://tengine.taobao.org/download/tengine-2.3.3.tar.gz
tar -xf tengine-2.3.3.tar.gz
```

### 下载 echo module 的源码包，并解压到 tengine 的 module 目录（假设 tengine 目录在 /app/download/tengine-2.3.3）
```bash
wget https://codeload.github.com/openresty/echo-nginx-module/tar.gz/refs/tags/v0.62
tar -xf echo-nginx-module-0.62 -C app/download/tengine-2.3.3/modules/echo-nginx-module
```

### 编译
```bash
/app/download/tengine-2.3.3/configure --prefix=/app/tengine --add-module=/app/download/tengine-2.3.3/modules/echo-nginx-module --add-module=/app/download/tengine-2.3.3/modules/ngx_http_upstream_check_module --with-stream --with-stream_ssl_module
make && make install

```

## 配置说明
配置文件有三个：
```bash
conf
├── nginx.conf
├── data_import.cof # 数据接收 server
└── nginx_monitor.conf # 探活用的 server 

```

### nginx.conf 

核心是定义了 `sa_extractor` 这个 log_format，方便后续神策的程序解析数据

```bash
http {
    include mime.types;

    map $http_x_forwarded_for  $clientRealIp {
        ""    $remote_addr;
        ~^(?P<firstAddr>[0-9\.]+),?.*$    $firstAddr;
    }

    log_format main '$clientRealIp - $remote_user [$time_local] $http_x_request_id "$request" $request_time $status $body_bytes_sent "$http_referer" "$http_user_agent" "$http_x_forwarded_for" "$request_body" "$upstream_addr"';
    log_format sa_extractor '"$proxy_add_x_forwarded_for" ++_ "$msec" ++_ "$request_method" ++_ "$arg_gzip" ++_ "$arg_data" ++_ "$arg_data_list" ++_ "$request_body" ++_ "$http_user_agent" ++_ "$arg_project" ++_ "$http_cookie" ++_ "$arg_token" ++_ "$arg_ext"';

    gzip  on;
    gzip_types text/plain text/css application/json application/javascript application/octet-stream;
    proxy_cache_path /sensorsdata/stdata/nginx/res keys_zone=config_cache:10m inactive=365d;

    access_log off;
    server_tokens off;

    # 8106 数据接入
    include data_import.conf;

    # 8108 监控
    include nginx_monitor.conf;

    default_type  application/octet-stream;

    #keepalive_timeout  0;
    keepalive_timeout  65;

	…
}

```

### data_import.conf

核心部分是 sa 和 sa.gif 作为数据接收的 URI，并按时间对日志文件进行切分

```bash
server {
	## Tengine 内置了时间的 var，如果使用的是 Nginx/OpenResty 则需要去掉注释
	# if ($$time_iso8601 ~ "^(\d{4})-(\d{2})-(\d{2})T(\d{2})") {
	# 	set $$year $$1;
	# 	set $$month $$2;
	# 	set $$day $$3;
	# 	set $$hour $$4;
	# }

    listen 8106;

    open_log_file_cache max=8;
    access_log /sensorsdata/stdata/nginx/others_log_for_debug.$year$month$day main;

    client_max_body_size 8m;
    client_body_buffer_size 8m;
    client_body_in_single_buffer on;

    location = /echo {
        add_header Cache-Control 'no-cache, no-store, must-revalidate';
        add_header Content-Type "text/plain";
        return 200;
    }

    location /sa.gif {
        add_header 'Access-Control-Allow-Origin' '*';
        if ($request_method = 'OPTIONS') {
            access_log off;
            return 204;
        }
        add_header Cache-Control 'no-cache, no-store, must-revalidate';
        add_header Pragma 'no-cache';
        add_header Expires 'Mon, 28 Sep 1970 05:00:00 GMT';
        access_log /sensorsdata/stdata/nginx/access_log.$year$month$day$hour sa_extractor;
        if ($request_method = 'POST') {
            echo_read_request_body;
        }
        empty_gif;
    }

    location /sa {
        add_header Cache-Control 'no-cache, no-store, must-revalidate';
        echo_read_request_body;
        access_log /sensorsdata/stdata/nginx/access_log.$year$month$day$hour sa_extractor;
    }
}
```

额外注意一下配置中日志的目录，需要保证 Nginx 的 user 有对应的写权限。


## Docker Demo
也可以直接下载本项目，使用项目提供的 Dockerfile 构建一个 demo 镜像。