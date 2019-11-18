## PHP with fpm and nginx 
PHP docker image based on official one with pre-installed extensions and tools.
Additionally we added here nginx with listening on 8080 port.


### Download
Grab it by running
```
docker pull codibly/php:7.4.0-RC
```

available versions:
* 7.4.0RC

### Run
Type
```
docker run --name some-php -d -v /your/directory/with/php/public:/opt/app/public -p 8080:8080 codibly/nginx-php
```

That will start supervisor which run php-fpm daemon and nginx listening on 8080.

Logs are written to STDOUT, examine them running

```
docker logs some-php -f
```
