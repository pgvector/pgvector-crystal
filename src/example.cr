require "db"
require "pg"

db = DB.open("postgres://localhost/pgvector_crystal_test")
db.exec "CREATE EXTENSION IF NOT EXISTS vector"
db.exec "DROP TABLE IF EXISTS items"
db.exec "CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3))"

embedding1 = "[1,1,1]"
embedding2 = "[2,2,2]"
embedding3 = "[1,1,2]"
db.exec "INSERT INTO items (embedding) VALUES ($1), ($2), ($3)", embedding1, embedding2, embedding3

embedding = "[1,1,1]"
db.query("SELECT id, embedding::text FROM items ORDER BY embedding <-> $1 LIMIT 5", embedding) do |rs|
  rs.each do
    id, embedding = rs.read(Int64, String)
    puts "#{id}: #{embedding}"
  end
end

db.close
