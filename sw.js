const C="rb-v2",A=["./","index.html","manifest.webmanifest","icon-192.png"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(A)));self.skipWaiting()});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))));self.clients.claim()});
self.addEventListener("fetch",e=>{const u=new URL(e.request.url);
 if(e.request.method!=="GET"||u.origin!==location.origin)return;
 const dyn=e.request.mode==="navigate"||/version\.json|config\.js|admin\.js|index\.html|\/$/.test(u.pathname);
 if(dyn){e.respondWith(fetch(e.request).then(r=>{if(r.ok&&!/admin\.js|config\.js|version\.json/.test(u.pathname)){const c=r.clone();caches.open(C).then(x=>x.put(e.request,c))}return r}).catch(()=>caches.match(e.request).then(m=>m||caches.match("index.html"))));return}
 e.respondWith(caches.match(e.request).then(m=>{const f=fetch(e.request).then(r=>{if(r.ok){const c=r.clone();caches.open(C).then(x=>x.put(e.request,c))}return r}).catch(()=>m);return m||f}))});
