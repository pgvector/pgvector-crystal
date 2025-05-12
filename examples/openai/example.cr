require "db"
require "http/client"
require "json"
require "pg"

db = DB.open("postgres://localhost/pgvector_example")
db.exec "CREATE EXTENSION IF NOT EXISTS vector"
db.exec "DROP TABLE IF EXISTS documents"
db.exec "CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding vector(1536))"

def embed(input)
  api_key = ENV.fetch("OPENAI_API_KEY")
  url = "https://api.openai.com/v1/embeddings"
  data = {
    "input" => input,
    "model" => "text-embedding-3-small",
  }
  headers = HTTP::Headers.new
  headers["Authorization"] = "Bearer #{api_key}"
  headers["Content-Type"] = "application/json"

  response = HTTP::Client.post url, headers, data.to_json
  JSON.parse(response.body)["data"].as_a.map { |v| v["embedding"] }
end

documents = ["The dog is barking", "The cat is purring", "The bear is growling"]
embeddings = embed(documents)
documents.zip(embeddings) do |content, embedding|
  db.exec "INSERT INTO documents (content, embedding) VALUES ($1, $2)", content, embedding.to_json
end

query = "forest"
embedding = embed([query])[0]
db.query("SELECT content FROM documents ORDER BY embedding <=> $1 LIMIT 5", embedding) do |rs|
  rs.each do
    puts rs.read(String)
  end
end

db.close
