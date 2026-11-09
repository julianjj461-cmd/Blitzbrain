// BLITZBRAIN Smoke-Test: startet jedes Spiel einzeln und tippt zufällig herum.
// Meldet JS-Fehler und Spiele, die sofort abstürzen. Aufruf:  node tests/smoke.js [pfad/zur/index.html]
const {chromium}=require('playwright');const path=require('path');
const file='file://'+path.resolve(process.argv[2]||path.join(__dirname,'..','index.html'));
(async()=>{const b=await chromium.launch();let bad=0;
 const p0=await (await b.newContext({viewport:{width:390,height:700},isMobile:true,hasTouch:true})).newPage();await p0.goto(file);await p0.waitForTimeout(300);
 const keys=await p0.evaluate(()=>POOL());await p0.context().close();
 for(const k of keys){const c=await b.newContext({viewport:{width:390,height:700},isMobile:true,hasTouch:true});const p=await c.newPage();const errs=[];p.on('pageerror',e=>errs.push(e.message));
  await p.route('**/*supabase.co/**',r=>r.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await p.goto(file);await p.waitForTimeout(200);await p.evaluate(k=>{DB.seen=1;DB.arc={};arcRun(k,12345)},k);
  for(let i=0;i<14;i++){await p.waitForTimeout(150);
   const els=await p.$$('#stg button, #stg .tile, #stg [data-v], #stg [data-i], #stg [data-k], #stg input');
   for(const el of els.sort(()=>Math.random()-.5).slice(0,3)){try{await el.click({timeout:300,force:true})}catch(e){}}}
  const alive=await p.evaluate(()=>!!document.getElementById('stg')||/Bestzeit|Fehlerfrei|Strafzeit/.test(document.body.innerText));
  const ok=!errs.length&&alive;if(!ok)bad++;console.log((ok?'OK  ':'FAIL')+' '+k+(errs.length?'  → '+errs[0]:alive?'':'  → Bildschirm leer'));await c.close()}
 await b.close();console.log(bad?`\n${bad} Spiel(e) mit Problemen`:`\nAlle ${keys.length} Spiele laufen ohne Fehler.`);process.exit(bad?1:0)})();
