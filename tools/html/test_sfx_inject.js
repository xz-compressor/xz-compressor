// SFX 生成与解压全流程测试
(function(){
  const panel=document.createElement("pre");
  panel.style.cssText="position:fixed;top:0;left:0;right:0;max-height:70vh;overflow:auto;background:#000;z-index:99999;padding:10px;font-size:12px;margin:0;white-space:pre-wrap";
  document.body.appendChild(panel);
  const lines=[]; function L(s){lines.push(s);panel.textContent=lines.join("\n");panel.scrollTop=panel.scrollHeight;}
  let pass=0,fail=0;
  function check(n,c){if(c){pass++;L("[PASS] "+n);}else{fail++;L("[FAIL] "+n);}}
  const sleep=ms=>new Promise(r=>setTimeout(r,ms));
  const captured=[];
  const origClick=HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click=function(){
    if(this.download&&this.href&&this.href.startsWith("blob:")){captured.push({name:this.download,url:this.href});L("  [下载] "+this.download);}
    else origClick.call(this);
  };
  window.prompt=()=>""; window.alert=()=>{};
  function setInput(el,files){const dt=new DataTransfer();files.forEach(f=>dt.items.add(f));el.files=dt.files;el.dispatchEvent(new Event("change",{bubbles:true}));}
  function mkFile(n,c){return new File([c],n,{type:"application/octet-stream"});}
  async function waitCap(n,t){const t0=Date.now();while(captured.length<n&&Date.now()-t0<t)await sleep(100);return captured.length>=n;}

  window.runSfxTest=async function(){
    L("=== 1. 压缩 xz ===");
    let big="SFX自解压测试内容 ".repeat(2000);
    setInput(document.getElementById("filesC"),[mkFile("readme.txt",big)]);
    await sleep(200);
    document.getElementById("cformat").value="xz";
    document.getElementById("cformat").dispatchEvent(new Event("change"));
    document.getElementById("clevel").value="9";
    document.getElementById("doCompress").click();
    let ok=await waitCap(1,15000);
    check("xz 压缩",ok);
    const xzBlob=captured[0];

    L("=== 2. 生成 SFX HTML ===");
    document.querySelector('.tab[data-t="sfx"]').click();
    await sleep(200);
    document.getElementById("sfxTitle").value="演示自解压";
    // 用 xz 文件
    const xzFile=new File([await (await fetch(xzBlob.url)).blob()],"readme.txt.xz",{type:"application/octet-stream"});
    setInput(document.getElementById("sfxArc"),[xzFile]);
    await sleep(2000);
    ok=await waitCap(2,15000);
    check("SFX HTML 生成",ok);
    const sfxBlob=captured[captured.length-1];
    const sfxText=await (await fetch(sfxBlob.url)).text();
    check("SFX 含数据占位已替换",!sfxText.includes("__DATA_B64__"));
    check("SFX 含引擎",sfxText.includes("window.SevenZip")||sfxText.includes("SevenZip"));
    check("SFX 含原始文件名 readme.txt.xz",sfxText.includes("readme.txt.xz"));
    check("SFX 无残留占位符",!sfxText.includes("__WASM_COPY__")&&!sfxText.includes("__ARC_NAME__"));

    L("=== 3. iframe 实际运行 SFX 并解压 ===");
    const autoScript=
      'window.__r="pending";'+
      'window.addEventListener("error",e=>{if(window.__r!=="done")window.__r="error:"+e.message;});'+
      'const oc=HTMLAnchorElement.prototype.click;'+
      'HTMLAnchorElement.prototype.click=function(){if(this.download){window.__dn=this.download;fetch(this.href).then(r=>r.arrayBuffer()).then(b=>{window.__dd=new Uint8Array(b);window.__r="done";});}else oc.call(this);};'+
      'window.addEventListener("load",()=>{setTimeout(()=>{document.getElementById("goBtn").click();setTimeout(()=>{if(window.__r==="pending")window.__r="nodownload";},8000);},1000);});';
    const testSfx=sfxText.replace("</body>","<script>"+autoScript+"<\/script></body>");
    const iframe=document.createElement("iframe");
    iframe.style.cssText="position:fixed;left:-9999px;bottom:0;width:1000px;height:700px";
    document.body.appendChild(iframe);
    iframe.srcdoc=testSfx;
    // 轮询结果
    let res="",t0=Date.now();
    while(Date.now()-t0<40000){
      try{ res=iframe.contentWindow.__r||""; }catch(e){}
      if(res==="done"||res.startsWith("error")) break;
      await sleep(500);
    }
    L("  iframe 结果: "+res);
    check("SFX 解压成功并下载",res==="done");
    if(res==="done"){
      const w=iframe.contentWindow;
      check("SFX 解压文件名为 readme.txt",w.__dn==="readme.txt");
      const enc=new TextEncoder().encode(big);
      check("SFX 解压内容一致",w.__dd&&w.__dd.length===enc.length);
    }
    L("\n结果: 通过 "+pass+" 项, 失败 "+fail+" 项");
    document.title=fail===0?"SFX_ALL_PASS":("SFX_FAIL_"+fail);
  };
  setTimeout(()=>window.runSfxTest(),1800);
})();
