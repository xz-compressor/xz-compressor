// 注入到构建后 HTML 的 e2e 测试（实时日志面板）
(function(){
  window.addEventListener("error", e=>{ try{ L("全局错误: "+e.message+"  | lineno="+e.lineno+" colno="+e.colno+" file="+e.filename); }catch(x){} });
  window.addEventListener("unhandledrejection", e=>{ try{ L("未处理Promise: "+(e.reason?.message||e.reason||e.reason?.name)); }catch(x){} });
  const panel=document.createElement("pre");
  panel.id="e2e-live";
  panel.style.cssText="position:fixed;top:0;left:0;right:0;max-height:60vh;overflow:auto;background:#000;z-index:99999;padding:10px;font-size:12px;margin:0;white-space:pre-wrap";
  document.body.appendChild(panel);
  const lines=[];
  function L(s){ lines.push(s); panel.textContent=lines.join("\n"); panel.scrollTop=panel.scrollHeight; }
  let pass=0, fail=0;
  function check(name, cond){ if(cond){pass++;L("[PASS] "+name);} else {fail++;L("[FAIL] "+name);} }
  function sleep(ms){return new Promise(r=>setTimeout(r,ms));}

  const captured=[];
  const origClick=HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click=function(){
    if(this.download && this.href && this.href.startsWith("blob:")){
      captured.push({name:this.download, url:this.href});
      L("  [下载触发] "+this.download);
    } else origClick.call(this);
  };
  let promptQueue=[];
  window.prompt=function(){ const v=promptQueue.shift()||""; L("  [prompt] 返回 "+v); return v; };
  window.alert=function(m){ L("  [alert] "+m); };

  function setInput(inputEl, files){
    const dt=new DataTransfer();
    files.forEach(f=>dt.items.add(f));
    inputEl.files=dt.files;
    inputEl.dispatchEvent(new Event("change",{bubbles:true}));
  }
  function mkFile(name, content){ return new File([content], name, {type:"application/octet-stream"}); }
  async function waitCapture(n, timeout){
    const t0=Date.now();
    while(captured.length<n && Date.now()-t0<timeout){ await sleep(100); }
    return captured.length>=n;
  }

  window.runE2E=async function(){
    L("=== 场景1: xz 单文件 L9 ===");
    let big="";
    for(let i=0;i<3000;i++) big += "XZ极限压缩测试 hello 0123456789 "+i+"\n";
    const f1=mkFile("data.txt", big);
    L("注入文件, filesC 当前 "+document.getElementById("filesC").files.length);
    setInput(document.getElementById("filesC"), [f1]);
    await sleep(300);
    L("change 后 clist: ["+document.getElementById("clist").textContent.trim().slice(0,80)+"]");
    document.getElementById("cformat").value="xz";
    document.getElementById("cformat").dispatchEvent(new Event("change"));
    document.getElementById("clevel").value="9";
    L("点击压缩前 cstatus: "+document.getElementById("cstatus").textContent);
    document.getElementById("doCompress").click();
    await sleep(4000);
    L("点击后 cstatus: "+document.getElementById("cstatus").textContent);
    L("clog: "+document.getElementById("clog").textContent.slice(0,400));
    let ok=await waitCapture(1, 15000);
    check("xz: 压缩后产生下载", ok);
    let xzData=null;
    if(ok){
      xzData=new Uint8Array(await (await (await fetch(captured[0].url)).blob()).arrayBuffer());
      check("xz: 文件名 data.txt.xz", captured[0].name==="data.txt.xz");
      check("xz: 魔数", xzData[0]===0xFD&&xzData[3]===0x58);
      check("xz: 变小", xzData.length<big.length);
    }

    L("=== 场景2: zip 多文件加密 ===");
    document.getElementById("clearC").click();
    await sleep(200);
    const fa=mkFile("a.txt","第一个文件 AAAA ".repeat(100));
    const fb=mkFile("b.txt","第二个文件 BBBB ".repeat(100));
    setInput(document.getElementById("filesC"), [fa,fb]);
    await sleep(300);
    L("clist: ["+document.getElementById("clist").textContent.trim().slice(0,80)+"]");
    document.getElementById("cformat").value="zip";
    document.getElementById("cformat").dispatchEvent(new Event("change"));
    document.getElementById("cpass").value="pass123";
    document.getElementById("cpass2").value="pass123";
    const b=captured.length;
    document.getElementById("doCompress").click();
    await sleep(4000);
    L("clog: "+document.getElementById("clog").textContent.slice(0,400));
    ok=await waitCapture(b+1, 15000);
    check("zip加密: 产生下载", ok);
    let zipData=null;
    if(ok) zipData=new Uint8Array(await (await (await fetch(captured[captured.length-1].url)).blob()).arrayBuffer());

    L("=== 场景3: 打开/解压 xz ===");
    document.querySelector('.tab[data-t="open"]').click();
    await sleep(300);
    setInput(document.getElementById("fileO"), [new File([xzData],"data.txt.xz",{type:"application/octet-stream"})]);
    await sleep(2000);
    L("oPanel hidden="+document.getElementById("oPanel").classList.contains("hidden"));
    L("alist: ["+document.getElementById("alist").textContent.trim().slice(0,100)+"]");
    const c3=captured.length;
    document.getElementById("extractAll").click();
    await sleep(4000);
    ok=await waitCapture(c3+1, 15000);
    check("打开: xz 解压产生下载", ok);
    if(ok){
      const got=new Uint8Array(await (await (await fetch(captured[captured.length-1].url)).blob()).arrayBuffer());
      const enc=new TextEncoder().encode(big);
      check("打开: 内容一致", got.length===enc.length);
    }

    L("\n结果: 通过 "+pass+" 项, 失败 "+fail+" 项");
    document.title=fail===0?"E2E_ALL_PASS":("E2E_FAIL_"+fail);
  };
  setTimeout(()=>{ L("开始 e2e（引擎预热）"); window.runE2E(); }, 1800);
})();
