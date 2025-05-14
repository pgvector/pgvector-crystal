# good resources
# https://opensearch.org/blog/improving-document-retrieval-with-sparse-semantic-encoders/
# https://huggingface.co/opensearch-project/opensearch-neural-sparse-encoding-v1
#
# run with
# text-embeddings-router --model-id opensearch-project/opensearch-neural-sparse-encoding-v1 --pooling splade

require "db"
require "http/client"
require "json"
require "pg"

db = DB.open("postgres://localhost/pgvector_example")
db.exec "CREATE EXTENSION IF NOT EXISTS vector"
db.exec "DROP TABLE IF EXISTS documents"
db.exec "CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding sparsevec(30522))"

def embed(inputs)
  url = "http://localhost:3000/embed_sparse"
  data = {
    "inputs" => inputs,
  }
  headers = HTTP::Headers.new
  headers["Content-Type"] = "application/json"

  response = HTTP::Client.post url, headers, data.to_json
  JSON.parse(response.body).as_a.map do |item|
    elements = item.as_a.map { |e| "#{e["index"].as_i + 1}:#{e["value"]}" }.join(",")
    "{#{elements}}/30522"
  end
end

documents = ["The dog is barking", "The cat is purring", "The bear is growling"]
embeddings = embed(documents)
documents.zip(embeddings) do |content, embedding|
  db.exec "INSERT INTO documents (content, embedding) VALUES ($1, $2)", content, embedding
end

query = "forest"
embedding = embed([query])[0]
db.query("SELECT content FROM documents ORDER BY embedding <#> $1 LIMIT 5", embedding) do |rs|
  rs.each do
    puts rs.read(String)
  end
end

db.close
