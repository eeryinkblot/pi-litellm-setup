"""Minimaler LiteLLM-Mock für den Smoke-Test: prüft den Bearer-Key und antwortet immer mit "OK"."""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT, KEY = int(sys.argv[1]), sys.argv[2]
MODELS = ["Mock-Model", "Mock Model 2($)"]


class Handler(BaseHTTPRequestHandler):
    def _authorized(self):
        if self.headers.get("Authorization") == f"Bearer {KEY}":
            return True
        self.send_response(401)
        self.end_headers()
        return False

    def _json(self, body):
        data = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if not self._authorized():
            return
        if self.path == "/v1/models":
            self._json({"data": [{"id": m, "object": "model"} for m in MODELS]})
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if not self._authorized():
            return
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        chunk = lambda delta, finish=None, **extra: {
            "id": "mock", "object": "chat.completion.chunk", "created": 0, "model": body["model"],
            "choices": [{"index": 0, "delta": delta, "finish_reason": finish}], **extra,
        }
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for event in (
            chunk({"role": "assistant", "content": "OK"}),
            chunk({}, "stop", usage={"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}),
        ):
            self.wfile.write(f"data: {json.dumps(event)}\n\n".encode())
        self.wfile.write(b"data: [DONE]\n\n")

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
