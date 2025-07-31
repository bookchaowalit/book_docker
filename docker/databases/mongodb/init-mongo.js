// MongoDB initialization script
// Creates application user and database

db = db.getSiblingDB('app_db');

db.createUser({
  user: 'app_user',
  pwd: 'app123',
  roles: [
    {
      role: 'readWrite',
      db: 'app_db'
    }
  ]
});

db.createCollection('users');
db.createCollection('logs');

print('MongoDB initialization completed');
