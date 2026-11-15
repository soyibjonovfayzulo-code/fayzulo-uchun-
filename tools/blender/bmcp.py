"""Minimal client for the Blender MCP add-on socket server (localhost:9876).

Usage: python bmcp.py <script.py> [args...]   -- runs the script inside the running Blender.
       python bmcp.py -c "<code>"
The executed code may set `result = {...}`; it is printed as JSON.
"""
import json
import socket
import sys


def send(code, host="localhost", port=9876, timeout=600.0):
    payload = (json.dumps({"type": "execute", "code": code, "strict_json": False}) + "\0").encode("utf-8")
    with socket.create_connection((host, port), timeout=timeout) as s:
        s.sendall(payload)
        buf = bytearray()
        while b"\0" not in buf:
            chunk = s.recv(65536)
            if not chunk:
                break
            buf.extend(chunk)
    return json.loads(bytes(buf).split(b"\0")[0].decode("utf-8"))


if __name__ == "__main__":
    if sys.argv[1] == "-c":
        code = sys.argv[2]
    else:
        path = sys.argv[1]
        with open(path, "r", encoding="utf-8") as f:
            code = f.read()
        code = "import sys\nsys.argv = %r\n__file__ = %r\n__name__ = '__main__'\n" % ([path] + sys.argv[2:], path) + code
    resp = send(code)
    if resp.get("stdout"):
        print(resp["stdout"])
    if resp.get("stderr"):
        print(resp["stderr"], file=sys.stderr)
    if resp.get("status") != "ok":
        print("BLENDER ERROR:", resp.get("message"), file=sys.stderr)
        sys.exit(1)
    print(json.dumps(resp.get("result"), ensure_ascii=False))
