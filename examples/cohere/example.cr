require "db"
require "http/client"
require "json"
require "pg"

db = DB.open("postgres://localhost/pgvector_example")
db.exec "CREATE EXTENSION IF NOT EXISTS vector"
db.exec "DROP TABLE IF EXISTS documents"
db.exec "CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding bit(1536))"

def embed(texts, input_type)
  api_key = ENV.fetch("CO_API_KEY")
  url = "https://api.cohere.com/v2/embed"
  data = {
    "texts"           => texts,
    "model"           => "embed-v4.0",
    "input_type"      => input_type,
    "embedding_types" => ["ubinary"],
  }
  headers = HTTP::Headers.new
  headers["Authorization"] = "Bearer #{api_key}"
  headers["Content-Type"] = "application/json"

  response = HTTP::Client.post url, headers, data.to_json
  JSON.parse(response.body)["embeddings"]["ubinary"].as_a.map { |e| e.as_a.map { |v| sprintf("%08b", v.as_i.to_u8) }.join }
end

documents = ["The dog is barking", "The cat is purring", "The bear is growling"]
embeddings = embed(documents, "search_document")
documents.zip(embeddings) do |content, embedding|
  db.exec "INSERT INTO documents (content, embedding) VALUES ($1, $2)", content, embedding
end

query = "forest"
embedding = embed([query], "search_query")[0]
db.query("SELECT content FROM documents ORDER BY embedding <~> $1 LIMIT 5", embedding) do |rs|
  rs.each do
    puts rs.read(String)
  end
end

db.close
