#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HOST = "0.0.0.0"
PORT = 3002
BACKEND = "B"
ETAG = '"status-v1"'

class Handler(BaseHTTPRequestHandler):
    def _send(self, status, body=None):
        self.send_response(status)
        self.send_header("X-Backend", BACKEND)
        self.send_header("Cache-Control", "public, max-age=60")
        self.send_header("ETag", ETAG)
        if body is not None:
            data = body.encode("utf-8")
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path
        if path not in ("/", "/api/status"):
            self._send(404, json.dumps({"error": "Not Found"}))
            return
        if self.headers.get("If-None-Match") == ETAG:
            self._send(304)
            return
        body = json.dumps({"backend": BACKEND, "status": "ok"})
        self._send(200, body)

    def log_message(self, fmt, *args):
        print(f"[Backend {BACKEND}] {self.address_string()} - {fmt % args}")

server = ThreadingHTTPServer((HOST, PORT), Handler)
print(f"Backend {BACKEND} listening on {HOST}:{PORT}")
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    server.server_close()
