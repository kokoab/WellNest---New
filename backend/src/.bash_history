php artisan reverb:start --host=0.0.0.0 --port=8081
docker compose exec backend_app bash 
php artisan reverb:start --host=0.0.0.0 --port=8080 -d
php artisan reverb:start -d --host=0.0.0.0 --port=8080
php artisan reverb:start --host=0.0.0.0 --port=8080
 docker compose up -d --build database backend_app backend_nginx reverb queue_worker
bash
