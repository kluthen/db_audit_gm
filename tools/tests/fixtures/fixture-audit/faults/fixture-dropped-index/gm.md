# fixture-dropped-index

Test-only state fault. Planted after the data load by dropping the index
on `orders (customer_id)`; fixed by any valid index leading with that
column (`CREATE INDEX ON orders (customer_id)`).
