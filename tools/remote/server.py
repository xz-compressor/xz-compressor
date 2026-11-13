# -*- coding: utf-8 -*-
"""
XZ 极速压缩工具 —— 远程更新公告 / 用户反馈服务端
用法:
    python server.py [端口]
默认监听 0.0.0.0:14923（本地隧道服务端口）。
配合 frp 等内网穿透工具，把本端口映射到公网，例如:
    frpc.ini:  [xz-remote]  type=tcp  local_ip=127.0.0.1  local_port=14923  remote_port=8350
客户端默认访问公网入口: http://<your-server>:<port>

接口:
    GET  /xz/announce   -> 公告内容（UTF-8 纯文本，第一行为标题，其余为正文）
    POST /xz/feedback   -> 提交用户反馈（表单字段见 FEED_FIELDS），写入 feedback.log
    GET  /              -> 服务状态探测

基础防 DDoS / 防滥用:
    - 请求体大小上限 64KB
    - 按 IP 限速: 每 IP 每分钟最多 3 次反馈 / 30 次任意请求
    - 字段长度硬校验（标题<=100、内容<=2000、联系方式<=200）
    - 反馈写追加日志，字段非法直接 400，不做任何重试/放大
更进一步的防护（按需）: 前置 Nginx 限流、验证码、静态公告 CDN、WAF。
"""
import json
import os
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE = os.path.dirname(os.path.abspath(__file__))
ANNOUNCE_FILE = os.path.join(BASE, "announce.txt")
FEEDBACK_LOG = os.path.join(BASE, "feedback.log")

FEED_FIELDS = {
    "app":     (0, 32),
    "ver":     (0, 32),
    "type":    (0, 16),
    "title":   (1, 100),
    "content": (1, 2000),
    "contact": (0, 200),
}
MAX_BODY = 64 * 1024          # 请求体上限 64KB
RATE_FEEDBACK = (3, 60)       # 反馈: 每 IP 60 秒内最多 3 次
RATE_ANY = (30, 60)           # 任意请求: 每 IP 60 秒内最多 30 次

_hits = {}                    # ip -> [(ts, kind), ...]  (内存限速，重启清零)


def rate_ok(ip, kind):
    now = time.time()
    limit, window = (RATE_FEEDBACK if kind == "fb" else RATE_ANY)
    lst = [t for (t, k) in _hits.get(ip, []) if now - t < window and (kind == "fb" or k == "any")]
    if len(lst) >= limit:
        return False
    _hits.setdefault(ip, []).append((now, kind))
    if len(_hits[ip]) > 200:
        _hits[ip] = _hits[ip][-200:]
    return True


def send_json(h, code, obj):
    body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
    h.send_response(code)
    h.send_header("Content-Type", "application/json; charset=utf-8")
    h.send_header("Content-Length", str(len(body)))
    h.send_header("Cache-Control", "no-store")
    h.end_headers()
    h.wfile.write(body)


class Handler(BaseHTTPRequestHandler):
    server_version = "XZRemote/1.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), fmt % args))

    def _ip(self):
        return self.client_address[0]

    def do_GET(self):
        ip = self._ip()
        if not rate_ok(ip, "any"):
            send_json(self, 429, {"ok": False, "error": "请求过于频繁"})
            return
        p = urllib.parse.urlparse(self.path)
        if p.path == "/":
            send_json(self, 200, {"ok": True, "service": "xz-remote", "time": int(time.time())})
        elif p.path == "/xz/announce":
            try:
                with open(ANNOUNCE_FILE, "r", encoding="utf-8") as f:
                    text = f.read()
            except OSError:
                send_json(self, 500, {"ok": False, "error": "公告文件缺失"})
                return
            body = text.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.wfile.write(body)
        else:
            send_json(self, 404, {"ok": False, "error": "not found"})

    def do_POST(self):
        ip = self._ip()
        p = urllib.parse.urlparse(self.path)
        if p.path != "/xz/feedback":
            send_json(self, 404, {"ok": False, "error": "not found"})
            return
        if not rate_ok(ip, "fb"):
            send_json(self, 429, {"ok": False, "error": "提交过于频繁，请稍后再试"})
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY:
            send_json(self, 413, {"ok": False, "error": "请求体为空或过大"})
            return
        raw = self.rfile.read(length)
        try:
            form = urllib.parse.parse_qs(raw.decode("utf-8", "replace"), keep_blank_values=True)
        except Exception:
            send_json(self, 400, {"ok": False, "error": "表单解析失败"})
            return
        data = {}
        for key, (min_len, max_len) in FEED_FIELDS.items():
            v = (form.get(key) or [""])[0].strip()
            if len(v) < min_len or len(v) > max_len:
                send_json(self, 400, {"ok": False, "error": "字段 %s 长度不在 %d-%d" % (key, min_len, max_len)})
                return
            data[key] = v
        record = {"time": time.strftime("%Y-%m-%d %H:%M:%S"), "ip": ip, "fields": data}
        try:
            with open(FEEDBACK_LOG, "a", encoding="utf-8") as f:
                f.write(json.dumps(record, ensure_ascii=False) + "\n")
        except OSError:
            send_json(self, 500, {"ok": False, "error": "写入失败"})
            return
        send_json(self, 200, {"ok": True, "msg": "反馈已收到，感谢支持"})

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()


def main():
    port = 14923
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
    srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print("XZRemote 服务已启动: http://0.0.0.0:%d  (公告=%s, 反馈日志=%s)" % (port, ANNOUNCE_FILE, FEEDBACK_LOG))
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()


if __name__ == "__main__":
    main()
