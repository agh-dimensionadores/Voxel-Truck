#!/usr/bin/env python3
"""Proxy local de desarrollo: reenvía al backend y agrega headers CORS."""

from __future__ import annotations

import argparse
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CORS_HEADERS = {
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Authorization, Content-Type, Accept",
    "Access-Control-Max-Age": "600",
    "Access-Control-Allow-Private-Network": "true",
}


class ProxyHandler(BaseHTTPRequestHandler):
    target: str = ""

    def _apply_cors(self) -> None:
        origin = self.headers.get("Origin")
        if origin:
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Vary", "Origin")
        else:
            self.send_header("Access-Control-Allow-Origin", "*")
        for key, value in CORS_HEADERS.items():
            self.send_header(key, value)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._apply_cors()
        self.end_headers()

    def _proxy(self) -> None:
        url = self.target.rstrip("/") + self.path
        headers: dict[str, str] = {}
        if auth := self.headers.get("Authorization"):
            headers["Authorization"] = auth
        if accept := self.headers.get("Accept"):
            headers["Accept"] = accept
        if content_type := self.headers.get("Content-Type"):
            headers["Content-Type"] = content_type

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else None
        request = urllib.request.Request(url, data=body, headers=headers, method=self.command)

        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                payload = response.read()
                self.send_response(response.status)
                self._apply_cors()
                if response.content_type:
                    self.send_header("Content-Type", response.content_type)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except urllib.error.HTTPError as error:
            payload = error.read()
            self.send_response(error.code)
            self._apply_cors()
            if error.headers.get_content_type():
                self.send_header("Content-Type", error.headers.get_content_type())
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except Exception as error:  # noqa: BLE001 - proxy de desarrollo
            message = str(error).encode("utf-8")
            self.send_response(502)
            self._apply_cors()
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(message)))
            self.end_headers()
            self.wfile.write(message)

    def do_GET(self) -> None:
        self._proxy()

    def do_POST(self) -> None:
        self._proxy()

    def do_PUT(self) -> None:
        self._proxy()

    def do_PATCH(self) -> None:
        self._proxy()

    def do_DELETE(self) -> None:
        self._proxy()

    def log_message(self, format: str, *args) -> None:
        print(f"[proxy] {self.address_string()} - {format % args}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Proxy API con CORS para desarrollo web.")
    parser.add_argument("--target", required=True, help="URL base del backend")
    parser.add_argument("--port", type=int, default=18765, help="Puerto local")
    args = parser.parse_args()

    ProxyHandler.target = args.target
    server = ThreadingHTTPServer(("127.0.0.1", args.port), ProxyHandler)
    print("==> Proxy API dev")
    print(f"    Local:  http://127.0.0.1:{args.port}")
    print(f"    Remoto: {args.target}")
    print("    Ctrl+C para detener")
    server.serve_forever()


if __name__ == "__main__":
    main()
