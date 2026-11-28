-- The schema of the lists app. The PostgreSQL server of docker-compose.yml
-- runs this file when it starts with an empty database.

CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text NOT NULL,
  share_token text NOT NULL DEFAULT md5(random()::text)
);

CREATE TABLE items (
  id serial PRIMARY KEY,
  list_id integer NOT NULL REFERENCES lists (id),
  title text NOT NULL CONSTRAINT item_title_length
    CHECK (length(title) BETWEEN 1 AND 40)
);
