FROM php:8.4-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Allow multi‑MB image uploads (must stay ≥ Laravel validation max per file)
COPY php/uploads.ini /usr/local/etc/php/conf.d/uploads.ini

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www

# Copy existing application directory contents
COPY src/ /var/www

# Set permissions
# After COPY, create the required directories if they don't exist
RUN mkdir -p /var/www/storage /var/www/bootstrap/cache && \
    chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache && \
    chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Switch to non-root user
USER www-data

EXPOSE 9000
# Bypass broken image entrypoint (e.g. CRLF on Windows) by running php-fpm directly
ENTRYPOINT []
CMD ["php-fpm"]