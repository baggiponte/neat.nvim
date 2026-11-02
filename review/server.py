#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Loopback-only server for the cmdline.nvim review.

Serves index.html, the demo recordings under ../demo/out/, and reads/writes
feedback.json next to this file. Nothing else.

    uv run server.py [--port N]   # N=0 (default) picks a free port
"""
import argparse
import json
import os
import socket
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
INDEX = HERE / "index.html"
FEEDBACK = HERE / "feedback.json"
PIDFILE = HERE / "server.pid"
PORTFILE = HERE / "server.port"
DEMO = (HERE.parent / "demo" / "out").resolve()
TYPES = {".gif": "image/gif", ".png": "image/png", ".mp4": "video/mp4"}
MAX_BODY = 1_000_000


def valid(d: object) -> bool:
    if not isinstance(d, dict) or not isinstance(d.get("items"), list):
        return False
    if not isinstance(d.get("overall_comment", ""), str):
        return False
    for it in d["items"]:
        if not isinstance(it, dict) or not isinstance(it.get("id"), str):
            return False
        if it.get("decision") not in ("yes", "no", "changes", None):
            return False
        if not isinstance(it.get("comment", ""), str):
            return False
    return True


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: bytes, ctype: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            self._send(200, INDEX.read_bytes(), "text/html; charset=utf-8")
        elif path == "/feedback.json":
            if FEEDBACK.exists():
                self._send(200, FEEDBACK.read_bytes(), "application/json")
            else:
                self._send(404, b'{"error":"no feedback yet"}', "application/json")
        elif path.startswith("/demo/"):
            target = (DEMO / path[len("/demo/"):]).resolve()
            ctype = TYPES.get(target.suffix)
            if ctype and target.is_relative_to(DEMO) and target.is_file():
                self._send(200, target.read_bytes(), ctype)
            else:
                self._send(404, b"not found", "text/plain")
        else:
            self._send(404, b"not found", "text/plain")

    def do_POST(self) -> None:
        if self.path.split("?", 1)[0] != "/feedback.json":
            return self._send(404, b"not found", "text/plain")
        # Only same-origin JSON: a cross-site form cannot send this content type without a preflight we never answer.
        if not self.headers.get("Content-Type", "").startswith("application/json"):
            return self._send(415, b'{"error":"application/json required"}', "application/json")
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0 or n > MAX_BODY:
            return self._send(413, b'{"error":"bad length"}', "application/json")
        try:
            data = json.loads(self.rfile.read(n))
        except ValueError:
            return self._send(400, b'{"error":"invalid json"}', "application/json")
        if not valid(data):
            return self._send(422, b'{"error":"unexpected shape"}', "application/json")
        fd, tmp = tempfile.mkstemp(dir=HERE, prefix=".feedback.", suffix=".tmp")
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write("\n")
        os.replace(tmp, FEEDBACK)
        self._send(200, b'{"ok":true}', "application/json")

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.log_date_time_string()} {fmt % args}", flush=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=0)
    port = ap.parse_args().port
    srv = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    srv.address_family = socket.AF_INET
    PIDFILE.write_text(f"{os.getpid()}\n")
    PORTFILE.write_text(f"{srv.server_address[1]}\n")
    print(f"serving http://127.0.0.1:{srv.server_address[1]}/  (pid {os.getpid()})", flush=True)
    try:
        srv.serve_forever()
    finally:
        PIDFILE.unlink(missing_ok=True)
        PORTFILE.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
