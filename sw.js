const V='bb-v12',FILES=['./','./index.html','./manifest.webmanifest','./icon5-192.png','./icon5-512.png','./icon5-maskable-512.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{const r=e.request,u=new URL(r.url);
 if(r.method!=='GET'||u.origin!==location.origin)return; // Supabase & Co. nie cachen
 e.respondWith(fetch(r).then(res=>{if(res.ok){const c=res.clone();caches.open(V).then(x=>x.put(r,c))}return res}).catch(()=>caches.match(r).then(m=>m||caches.match('./index.html'))))});
self.addEventListener('notificationclick',e=>{e.notification.close();e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(l=>{for(const c of l){if('focus' in c)return c.focus()}return self.clients.openWindow('./')}))});

self.addEventListener('push',e=>{let d={};try{d=e.data.json()}catch(x){}
 e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(l=>{if(l.some(c=>c.visibilityState==='visible'))return;return self.registration.showNotification(d.title||'BLITZBRAIN',{body:d.body||'',icon:'icon5-192.png',tag:d.tag||'bb'})}))});
