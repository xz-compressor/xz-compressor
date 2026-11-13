# -*- coding: utf-8 -*-
"""XZ 公告/投票/反馈/设备 服务器（单文件零依赖）。默认监听 14923"""
import json, os, sys, time, threading, html
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 14923
ADMIN_PASS = os.environ.get("XZ_ADMIN_PASS", "changeme")  # 部署时通过环境变量 XZ_ADMIN_PASS 设置强口令，勿在代码内写死
DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
ANNOUNCE_FILE = os.path.join(DATA_DIR, "announcement.json")
FEEDBACK_FILE = os.path.join(DATA_DIR, "feedback.log")
POLLS_FILE = os.path.join(DATA_DIR, "polls.json")
DEVICES_FILE = os.path.join(DATA_DIR, "devices.log")
GLOBAL_RATE_PER_SEC = 8
RATE_FEEDBACK_SEC = 60
RATE_VOTE_SEC = 5
RATE_ANNOUNCE_SEC = 15
os.makedirs(DATA_DIR, exist_ok=True)

_lock = threading.Lock(); _rate = {}; _hits = {}; _devseen = set()
def _now(): return time.strftime("%Y-%m-%d %H:%M:%S")

def global_allow(ip):
    now = time.time()
    with _lock:
        arr = _hits.setdefault(ip, [])
        arr[:] = [t for t in arr if now - t < 1.0]
        if len(arr) >= GLOBAL_RATE_PER_SEC: return False
        arr.append(now); return True

def rate_ok(ip, key, sec):
    now = time.time()
    with _lock:
        rec = _rate.setdefault(ip, {})
        if now - rec.get(key, 0) < sec: return False
        rec[key] = now; return True

def load_json(p, d):
    if os.path.exists(p):
        try: return json.load(open(p, encoding="utf-8"))
        except: pass
    return d
def save_json(p, o): json.dump(o, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
def append_line(p, d):
    d = dict(d); d["ts"] = _now()
    with open(p, "a", encoding="utf-8") as f: f.write(json.dumps(d, ensure_ascii=False)+"\n")

def record_device(ip, ua, devid, path):
    if not devid: return
    with _lock:
        k = (devid, ip)
        if k in _devseen: return
        _devseen.add(k)
    append_line(DEVICES_FILE, {"device_id":devid,"ip":ip,"ua":ua[:200],"path":path})

def load_announces():
    d = load_json(ANNOUNCE_FILE, {"list":[]})
    if isinstance(d, list): d = {"list": d}
    return d.get("list", []) if isinstance(d, dict) else []

def _is_active(ts_deadline):
    if not ts_deadline: return True
    try: return time.time() < time.mktime(time.strptime(ts_deadline, "%Y-%m-%d %H:%M"))
    except: return False

def active_announces():
    return [a for a in load_announces() if _is_active(a.get("deadline",""))]

def load_polls():
    d = load_json(POLLS_FILE, {"polls":[]})
    return d if isinstance(d, dict) and "polls" in d else {"polls":[]}

def active_polls():
    out = []
    for p in load_polls()["polls"]:
        if _is_active(p.get("deadline","")):
            out.append({"id":p["id"],"q":p["q"],"opts":p["opts"],"deadline":p["deadline"]})
    return out

def cleanup_expired():
    """把已过期的公告、投票从数据文件中物理删除"""
    d = load_json(ANNOUNCE_FILE, {"list":[]})
    if isinstance(d, dict) and "list" in d:
        keep = [a for a in d["list"] if _is_active(a.get("deadline",""))]
        if len(keep) != len(d["list"]):
            d["list"] = keep; save_json(ANNOUNCE_FILE, d)
    dp = load_polls()
    keep = [p for p in dp["polls"] if _is_active(p.get("deadline",""))]
    if len(keep) != len(dp["polls"]):
        dp["polls"] = keep; save_json(POLLS_FILE, dp)

def poll_result(p):
    counts = [0]*len(p["opts"])
    for w,i in p.get("votes",{}).items():
        if 0<=i<len(counts): counts[i]+=1
    winner = ""
    if counts:
        mx = max(counts)
        if mx>0:
            wi = counts.index(mx)
            try:
                if not _is_active(p["deadline"]):
                    winner = p["opts"][wi]
            except: pass
    return counts, winner

# CSS 里的 { } 全部双写成 {{ }}，避免被 .format() 当占位符
ADMIN_HTML = """<!doctype html><html lang="zh"><head><meta charset="utf-8"><title>XZ后台</title><style>
body{{font-family:"Microsoft YaHei",sans-serif;max-width:820px;margin:24px auto;padding:0 16px;color:#222}}
h1{{font-size:20px}} h3{{font-size:16px;margin:6px 0}} .card{{border:1px solid #ddd;border-radius:8px;padding:16px;margin:12px 0}}
input,textarea{{width:100%;box-sizing:border-box;padding:8px;font-size:14px;font-family:inherit}}
textarea{{min-height:100px}} button{{background:#2b579a;color:#fff;border:0;padding:8px 18px;border-radius:5px;cursor:pointer}}
.msg{{padding:8px;border-radius:5px;margin:8px 0}} .ok{{background:#e6f4ea;color:#137333}} .err{{background:#fce8e6;color:#c5221f}}
.fb{{font-size:13px;border-bottom:1px solid #eee;padding:6px 0;word-break:break-all}}
.poll{{border:1px solid #e5e5e5;border-radius:6px;padding:10px;margin:8px 0}}
.bar{{height:14px;background:#2b579a;border-radius:3px;margin-top:2px}}
.delrow{{display:block;margin-top:8px;text-align:right}}
.delrow button{{padding:3px 12px;background:#c5221f;color:#fff;border:0;border-radius:4px;cursor:pointer;font-size:12px}}
a{{color:#2b579a}}
</style></head><body>
<h1>XZ 压缩工具 · 管理后台</h1>{msg}
<div class="card"><h3>发新公告（可发多条）</h3><form method="post" action="/admin/addann">
<input type="hidden" name="pw" value="{pw}">
<input name="title" placeholder="公告标题"><br><br>
<textarea name="body" placeholder="公告正文"></textarea><br><br>
<input name="deadline" placeholder="截止时间 2026-11-15 23:59（留空则永久有效）"><br><br>
<button type="submit">发布公告</button></form></div>
<div class="card"><h3>当前公告列表</h3>{ann}</div>
<div class="card"><h3>新建投票</h3><form method="post" action="/admin/newpoll">
<input type="hidden" name="pw" value="{pw}">
<input name="q" placeholder="投票问题"><br><br>
<input name="opts" placeholder="选项用 | 分隔，如：云同步|深色模式|更多格式"><br><br>
<input name="deadline" placeholder="截止时间 2026-11-15 23:59"><br><br>
<button type="submit">发布投票</button></form></div>
<div class="card"><h3>投票列表（截止后自动统计最高票）</h3>{polls}</div>
<div class="card"><h3>反馈记录（共 {fbtotal} 条）</h3>{fb}</div>
<div class="card"><h3>设备硬件码（最近 {devtotal} 台）</h3>{dev}</div>
<p><a href="/xz/announce" target="_blank">公告接口</a> · <a href="/xz/polls" target="_blank">投票接口</a> · <a href="/admin/logout">退出</a></p>
</body></html>"""

LOGIN_HTML = """<!doctype html><meta charset="utf-8"><body style="font-family:sans-serif;max-width:360px;margin:60px auto">
<h2>XZ 管理登录</h2><form method="post" action="/admin/login">
<input name="pw" type="password" style="width:100%;padding:8px"><br><br><button>登录</button></form>{msg}</body>"""

class H(BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def _send(self,code,body=b"",ct="text/plain; charset=utf-8"):
        if isinstance(body,str): body=body.encode("utf-8")
        self.send_response(code); self.send_header("Content-Type",ct)
        self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
    def _html(self,s): self._send(200,s.encode("utf-8"),"text/html; charset=utf-8")
    def _redirect(self,path,cookie=None):
        self.send_response(302); self.send_header("Location",path)
        if cookie: self.send_header("Set-Cookie",cookie)
        self.send_header("Content-Length","0"); self.end_headers()
    def _ip(self): return self.client_address[0]
    def _ua(self): return self.headers.get("User-Agent","")
    def _devid(self,form): return (self.headers.get("X-Device-Id") or form.get("device_id","") or "").strip()[:64]
    def _guard(self):
        if not global_allow(self._ip()): self._send(429,"too many requests"); return False
        record_device(self._ip(),self._ua(),self._devid({}),urlparse(self.path).path); return True
    def do_GET(self):
        u=urlparse(self.path).path
        if not self._guard(): return
        cleanup_expired()
        if u=="/xz/announce":
            if not rate_ok(self._ip(),"ann",RATE_ANNOUNCE_SEC): return self._send(429,"rate limited")
            items = active_announces()
            out = "\n\n".join((a.get("title","")+"\n"+a.get("body","")).strip() for a in items)
            return self._send(200, (out.strip()+"\n") if out.strip() else "暂无公告\n")
        if u=="/xz/polls": return self._send(200,json.dumps(active_polls(),ensure_ascii=False))
        if u=="/admin/logout": return self._redirect("/admin","xzadmin=0; path=/")
        if u=="/admin":
            if self.cookie_ok(): return self.render_admin("")
            return self._html(LOGIN_HTML.format(msg=""))
        self._send(404,"not found")
    def do_POST(self):
        u=urlparse(self.path).path
        if not self._guard(): return
        L=int(self.headers.get("Content-Length",0))
        raw=self.rfile.read(L).decode("utf-8") if L else ""
        form={k:v[0] for k,v in parse_qs(raw).items()}
        if u=="/xz/vote":
            if not rate_ok(self._ip(),"vote",RATE_VOTE_SEC): return self._send(429,json.dumps({"ok":False,"err":"rate limited"}))
            pid=form.get("poll_id","").strip(); devid=self._devid(form)
            try: idx=int(form.get("opt_idx","-1"))
            except: idx=-1
            d=load_polls(); ok=False; msg="投票不存在"
            for p in d["polls"]:
                if p["id"]==pid:
                    if not (0<=idx<len(p["opts"])): msg="选项无效"
                    elif not devid: msg="缺少设备标识"
                    elif devid in p.get("votes",{}): msg="你已投过票"
                    else:
                        p.setdefault("votes",{})[devid]=idx; save_json(POLLS_FILE,d); ok=True; msg="投票成功"
                    break
            return self._send(200,json.dumps({"ok":ok,"msg":msg},ensure_ascii=False))
        if u=="/xz/feedback":
            if not rate_ok(self._ip(),"fb",RATE_FEEDBACK_SEC): return self._send(429,json.dumps({"ok":False,"err":"rate limited"}))
            append_line(FEEDBACK_FILE,{"ip":self._ip(),"device_id":self._devid(form),
                "type":form.get("type",""),"title":form.get("title",""),
                "content":form.get("content",""),"contact":form.get("contact","")})
            return self._send(200,json.dumps({"ok":True}))
        if u=="/admin/login":
            if form.get("pw")==ADMIN_PASS: return self._redirect("/admin","xzadmin=1; path=/")
            return self._html(LOGIN_HTML.format(msg='<p class="msg err">密码错误</p>'))
        if u=="/admin/addann":
            if not self.cookie_ok() or form.get("pw")!=ADMIN_PASS: return self._send(403,"forbidden")
            t=form.get("title","").strip(); b=form.get("body","").strip(); dl=form.get("deadline","").strip()
            if not t and not b: return self.render_admin('<p class="msg err">标题或正文不能为空</p>')
            d = load_json(ANNOUNCE_FILE, {"list":[]})
            if not isinstance(d,dict): d={"list":[]}
            d.setdefault("list",[]).insert(0,{"id":time.strftime("%Y%m%d%H%M%S"),"title":t,"body":b,"deadline":dl,"ts":_now()})
            save_json(ANNOUNCE_FILE,d)
            return self.render_admin('<p class="msg ok">公告已发布</p>')
        if u=="/admin/delann":
            if not self.cookie_ok() or form.get("pw")!=ADMIN_PASS: return self._send(403,"forbidden")
            aid=form.get("id","").strip()
            d = load_json(ANNOUNCE_FILE, {"list":[]})
            if not isinstance(d,dict): d={"list":[]}
            d["list"]=[a for a in d.get("list",[]) if a.get("id")!=aid]
            save_json(ANNOUNCE_FILE,d)
            return self.render_admin('<p class="msg ok">公告已删除</p>')
        if u=="/admin/delpoll":
            if not self.cookie_ok() or form.get("pw")!=ADMIN_PASS: return self._send(403,"forbidden")
            pid=form.get("id","").strip()
            dp=load_polls()
            dp["polls"]=[p for p in dp["polls"] if p.get("id")!=pid]
            save_json(POLLS_FILE,dp)
            return self.render_admin('<p class="msg ok">投票已删除</p>')
        if u=="/admin/newpoll":
            if not self.cookie_ok() or form.get("pw")!=ADMIN_PASS: return self._send(403,"forbidden")
            q=form.get("q","").strip(); opts=[o.strip() for o in form.get("opts","").split("|") if o.strip()]
            dl=form.get("deadline","").strip()
            if q and len(opts)>=2:
                if not dl: dl=time.strftime("%Y-%m-%d 23:59",time.localtime(time.time()+7*86400))
                d=load_polls(); d["polls"].append({"id":time.strftime("%Y%m%d%H%M%S"),"q":q,"opts":opts,"deadline":dl,"votes":{}})
                save_json(POLLS_FILE,d); return self.render_admin('<p class="msg ok">投票已发布</p>')
            return self.render_admin('<p class="msg err">问题不能为空，选项至少2个（用|分隔）</p>')
        self._send(404,"not found")
    def cookie_ok(self): return "xzadmin=1" in self.headers.get("Cookie","")
    def render_admin(self,msg):
        cleanup_expired()
        ann_items = load_announces()
        ann_html = ""
        for a in ann_items:
            dl = a.get("deadline","") or "永久"
            ann_html += ('<div class="fb"><b>[{ts}]</b> <b>{ti}</b> '
                '<span style="color:#888">截止 {dl}</span><br>{c}'
                '<form class="delrow" method="post" action="/admin/delann">'
                '<input type="hidden" name="pw" value="{pw}"><input type="hidden" name="id" value="{aid}">'
                '<button type="submit">删除公告</button></form></div>').format(
                ts=html.escape(a.get("ts","")),ti=html.escape(a.get("title","")),dl=html.escape(dl),
                c=html.escape(a.get("body","")),aid=html.escape(a.get("id","")),pw=html.escape(ADMIN_PASS))
        ann_html = ann_html or "<p style='color:#888'>暂无公告</p>"
        fb=[]
        if os.path.exists(FEEDBACK_FILE):
            for ln in reversed(open(FEEDBACK_FILE,encoding="utf-8").read().splitlines()[-30:]):
                try:
                    d=json.loads(ln)
                    fb.append('<div class="fb"><b>[{ts}]</b> <b>{t}</b> {ip}<br><b>{ti}</b><br>{c}<br>联系:{ct}</div>'.format(
                        ts=html.escape(d.get("ts","")),t=html.escape(d.get("type","")),ip=html.escape(d.get("ip","")),
                        ti=html.escape(d.get("title","")),c=html.escape(d.get("content","")),ct=html.escape(d.get("contact",""))))
                except: pass
        ph=[]
        for p in load_polls()["polls"]:
            counts,winner=poll_result(p); total=sum(counts) or 1; bars=[]
            active=_is_active(p.get("deadline",""))
            for i,opt in enumerate(p["opts"]):
                bars.append('<div>{o}（{n}票）<div class="bar" style="width:{p}%"></div></div>'.format(
                    o=html.escape(opt),n=counts[i],p=int(counts[i]*100/total)))
            status = '<span style="color:#137333">进行中</span>' if active else '<span style="color:#888">已截止</span>'
            w='<p style="color:#137333;font-weight:bold">胜出：{w}</p>'.format(html.escape(winner)) if winner else ""
            delbtn=('<form class="delrow" method="post" action="/admin/delpoll">'
                '<input type="hidden" name="pw" value="{pw}"><input type="hidden" name="id" value="{pid}">'
                '<button type="submit">删除投票</button></form>').format(
                pw=html.escape(ADMIN_PASS),pid=html.escape(p.get("id","")))
            ph.append('<div class="poll"><b>{q}</b> 截止 {dl} · {st}{w}{b}{d}</div>'.format(
                q=html.escape(p["q"]),dl=html.escape(p["deadline"]),st=status,w=w,b="".join(bars),d=delbtn))
        dh=[]; seen=set()
        if os.path.exists(DEVICES_FILE):
            for ln in reversed(open(DEVICES_FILE,encoding="utf-8").read().splitlines()[-50:]):
                try:
                    d=json.loads(ln); did=d.get("device_id","")
                    if did in seen: continue
                    seen.add(did)
                    dh.append('<div class="fb"><code>{d}</code> · {ip} · {u}</div>'.format(
                        d=html.escape(did[:24]),ip=html.escape(d.get("ip","")),u=html.escape(d.get("ua","")[:80])))
                except: pass
        out=ADMIN_HTML.format(msg=msg,pw=html.escape(ADMIN_PASS),
            ann=ann_html,
            polls="".join(ph) or "<p style='color:#888'>暂无投票</p>",
            fb="".join(fb) or "<p style='color:#888'>暂无反馈</p>",fbtotal=len(fb),
            dev="".join(dh) or "<p style='color:#888'>暂无设备</p>",devtotal=len(seen))
        self._html(out)

if __name__=="__main__":
    print("XZ server on 0.0.0.0:%d"%PORT)
    print("admin: http://localhost:%d/admin"%PORT)
    HTTPServer(("0.0.0.0",PORT),H).serve_forever()
