
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Laptop - Product Details</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
</head>
<body>
  <main>
    <nav aria-label="Breadcrumb">
      <ul>
        <li><a href="/products">Products</a></li>
        <li>Laptop</li>
      </ul>
    </nav>

    <article>
      <header>
        <i data-lucide="package"></i>
        <h2>Laptop</h2>
      </header>
      
      <section>
        <dl>
          <dt>Product ID</dt>
          <dd>#1</dd>
          
          <dt>Price</dt>
          <dd>$999.99</dd>
          
          <dt>Stock</dt>
          <dd>15 units</dd>
        </dl>
      </section>
      
      <footer>
        <a href="/products" role="button">Back to Products</a>
      </footer>
    </article>
  </main>
  
  <script src="https://unpkg.com/lucide@latest"></script>
  <script>lucide.createIcons();</script>
</body>
</html>

{"id":1,"name":"Laptop","price":999.99,"stock":15}
<article>
  <header>
    <i data-lucide="package"></i>
    <h3>Laptop</h3>
  </header>
  <dl>
    <dt>Price</dt>
    <dd>$999.99</dd>
    <dt>Stock</dt>
    <dd>15 units</dd>
  </dl>
</article>

1,Laptop,999.99,15[{"id":1,"name":"Laptop","price":999.99,"stock":15},{"id":2,"name":"Mouse","price":29.99,"stock":50},{"id":3,"name":"Keyboard","price":79.99,"stock":30},{"id":4,"name":"Monitor","price":299.99,"stock":20}]id,name,price,stock
1,Laptop,999.99,15
2,Mouse,29.99,50
3,Keyboard,79.99,30
4,Monitor,299.99,20

HTTP/1.1 200 OK
content-type: application/json; charset=utf-8
content-length: 50
date: (the time of the request)
connection: keep-alive

{"id":1,"name":"Laptop","price":999.99,"stock":15}
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 18
date: (the time of the request)
connection: keep-alive

1,Laptop,999.99,15
HTTP/1.1 404 Not Found
content-type: text/html; charset=utf-8
content-length: 46
date: (the time of the request)
connection: keep-alive

<h1>404 Not Found</h1><p>Product not found</p>
200 text/html; charset=utf-8
