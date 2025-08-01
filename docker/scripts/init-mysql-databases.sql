-- Create databases for different applications
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE DATABASE IF NOT EXISTS ghost;
CREATE DATABASE IF NOT EXISTS bookstack;
CREATE DATABASE IF NOT EXISTS mixpost;

-- Create application-specific users
CREATE USER IF NOT EXISTS 'wordpress'@'%' IDENTIFIED BY 'wordpress123';
CREATE USER IF NOT EXISTS 'ghost'@'%' IDENTIFIED BY 'ghost123';
CREATE USER IF NOT EXISTS 'bookstack'@'%' IDENTIFIED BY 'bookstack123';
CREATE USER IF NOT EXISTS 'mixpost'@'%' IDENTIFIED BY 'mixpost123';

-- Grant permissions
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%';
GRANT ALL PRIVILEGES ON ghost.* TO 'ghost'@'%';
GRANT ALL PRIVILEGES ON bookstack.* TO 'bookstack'@'%';
GRANT ALL PRIVILEGES ON mixpost.* TO 'mixpost'@'%';

FLUSH PRIVILEGES;
