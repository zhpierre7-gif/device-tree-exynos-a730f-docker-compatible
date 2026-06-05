#!/usr/bin/env python3
"""Simple HTTP server on port 3000"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import socket
import os

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html")
        self.end_headers()
        host = socket.gethostname()
        self.wfile.write(f"""<html><body style='font-family:monospace;padding:50px'>
<h1>Docker A730F Server</h1>
<p>Host: {host}</p>
<p>Path: {self.path}</p>
<p>Kernel: {os.uname().release}</p>
<p>Arch: {os.uname().machine}</p>
</body></html>""".encode())

    def log_message(self, format, *args):
        print(f"[{self.client_address[0]}] {args[0]}")

if __name__ == "__main__":
    print("Starting server on http://0.0.0.0:3000")
    HTTPServer(("0.0.0.0", 3000), Handler).serve_forever()
