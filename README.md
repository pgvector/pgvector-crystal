# pgvector-crystal

[pgvector](https://github.com/pgvector/pgvector) examples for Crystal

Supports [crystal-pg](https://github.com/will/crystal-pg)

[![Build Status](https://github.com/pgvector/pgvector-crystal/workflows/build/badge.svg?branch=master)](https://github.com/pgvector/pgvector-crystal/actions)

## Getting Started

Follow the instructions for your database library:

- [crystal-pg](#crystal-pg)

## crystal-pg

Create a table

```crystal
db.exec "CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3))"
```

Insert vectors

```crystal
embedding1 = "[1,1,1]"
embedding2 = "[2,2,2]"
embedding3 = "[1,1,2]"
db.exec "INSERT INTO items (embedding) VALUES ($1), ($2), ($3)", embedding1, embedding2, embedding3
```

Get the nearest neighbors

```crystal
embedding = "[1,1,1]"
db.query("SELECT id, embedding::text FROM items ORDER BY embedding <-> $1 LIMIT 5", embedding) do |rs|
  rs.each do
    id, embedding = rs.read(Int64, String)
    puts "#{id}: #{embedding}"
  end
end
```

See a [full example](src/example.cr)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/pgvector/pgvector-crystal/issues)
- Fix bugs and [submit pull requests](https://github.com/pgvector/pgvector-crystal/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development:

```sh
git clone https://github.com/pgvector/pgvector-crystal.git
cd pgvector-crystal
shards install
createdb pgvector_crystal_test
crystal src/example.cr
```
