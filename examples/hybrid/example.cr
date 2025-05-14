require "db"
require "http/client"
require "json"
require "pg"

db = DB.open("postgres://localhost/pgvector_example")
db.exec "CREATE EXTENSION IF NOT EXISTS vector"
db.exec "DROP TABLE IF EXISTS documents"
db.exec "CREATE TABLE documents (id bigserial PRIMARY KEY, content text, embedding vector(768))"
db.exec "CREATE INDEX ON documents USING GIN (to_tsvector('english', content))"

def embed(input, task_type)
  # nomic-embed-text uses a task prefix
  # https://huggingface.co/nomic-ai/nomic-embed-text-v1.5
  input = input.map { |v| "#{task_type}: #{v}" }

  url = "http://localhost:11434/api/embed"
  data = {
    "input" => input,
    "model" => "nomic-embed-text",
  }
  headers = HTTP::Headers.new
  headers["Content-Type"] = "application/json"

  response = HTTP::Client.post url, headers, data.to_json
  JSON.parse(response.body)["embeddings"].as_a.map { |v| v.as_a }
end

documents = ["The dog is barking", "The cat is purring", "The bear is growling"]
embeddings = embed(documents, "search_document")
documents.zip(embeddings) do |content, embedding|
  db.exec "INSERT INTO documents (content, embedding) VALUES ($1, $2)", content, embedding.to_json
end

sql = <<-SQL
WITH semantic_search AS (
    SELECT id, RANK () OVER (ORDER BY embedding <=> $2) AS rank
    FROM documents
    ORDER BY embedding <=> $2
    LIMIT 20
),
keyword_search AS (
    SELECT id, RANK () OVER (ORDER BY ts_rank_cd(to_tsvector('english', content), query) DESC)
    FROM documents, plainto_tsquery('english', $1) query
    WHERE to_tsvector('english', content) @@ query
    ORDER BY ts_rank_cd(to_tsvector('english', content), query) DESC
    LIMIT 20
)
SELECT
    COALESCE(semantic_search.id, keyword_search.id) AS id,
    COALESCE(1.0 / ($3::double precision + semantic_search.rank), 0.0) +
    COALESCE(1.0 / ($3::double precision + keyword_search.rank), 0.0) AS score
FROM semantic_search
FULL OUTER JOIN keyword_search ON semantic_search.id = keyword_search.id
ORDER BY score DESC
LIMIT 5
SQL
query = "growling bear"
embedding = embed([query], "search_query")[0]
k = 60
db.query(sql, query, embedding.to_json, k) do |rs|
  rs.each do
    id, score = rs.read(Int64, Float64)
    puts "document: #{id}, RRF score: #{score}"
  end
end

db.close
