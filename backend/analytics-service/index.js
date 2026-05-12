const http = require("http");

// Minimal stub so docker-compose nginx can resolve the analytics upstream at startup.
// Full implementation is optional; not production analytics.

const port = process.env.PORT ? Number(process.env.PORT) : 8082;

const server = http.createServer((req, res) => {
  const url = req.url || "/";

  if (req.method === "GET" && url.startsWith("/health")) {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "healthy", service: "analytics-service" }));
    return;
  }

  // Generic JSON response for any endpoint.
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ ok: true, service: "analytics-service", path: url }));
});

server.listen(port, "0.0.0.0", () => {
  // eslint-disable-next-line no-console
  console.log(`analytics-service stub listening on 0.0.0.0:${port}`);
});

