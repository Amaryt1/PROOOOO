'use strict';
const text = (v, n=4096) => typeof v==='string' && v.length<=n;
const url = v => text(v,2048) && /^https:\/\/[a-z\d.-]+(?::443)?(?:[/?#][^\s\\]*)?$/i.test(v);
const image = v => v==='' || url(v);
const obj = v => v && typeof v==='object' && !Array.isArray(v);
const int = v => Number.isSafeInteger(v) && v>=1;
const id = v => text(v,80) && /^[a-zA-Z0-9_-]+$/.test(v);
const flag = v => typeof v==='boolean';
function message(m) {
  return obj(m) && flag(m.enabled) && ['title','body','action','contact'].every(k=>text(m[k]))
    && m.title.length && m.action.length && image(m.image) && image(m.contactURL);
}
function validConfig(c) {
  if(!obj(c) || c.schema!==1 || !int(c.version) || c.modsURL!=='https://raw.githubusercontent.com/Amaryt1/PROOOOO/main/mods.json') return false;
  if(!obj(c.identity) || !text(c.identity.name,80) || !/^#[a-f\d]{6}$/i.test(c.identity.accent) || !image(c.identity.logo)) return false;
  if(!obj(c.social) || !['telegram','instagram','tiktok'].every(k=>url(c.social[k])) || !obj(c.sections) || !flag(c.sections.mods)) return false;
  if(![c.welcome,c.notification].every(m=>message(m) && id(m.id) && ['once','launch'].includes(m.frequency))) return false;
  const u=c.update;
  return !!(message(u) && int(u.minimum) && int(u.latest) && u.latest>=u.minimum && url(u.url) && text(u.expiresUTC)
    && (u.expiresUTC==='' || (Number.isFinite(Date.parse(u.expiresUTC)) && /Z$/.test(u.expiresUTC)))
    && Array.isArray(u.features) && u.features.length<=25 && u.features.every(x=>text(x,240))
    && Array.isArray(c.news) && c.news.length<=40 && c.news.every(x=>text(x,500)));
}
function modFiles(m) {
  if ('files' in m) return m.files;
  return [{name:m.id+'.'+m.extension,url:m.url,size:m.size,sha256:m.sha256,extension:m.extension}];
}
function validFiles(files) {
  if (!Array.isArray(files) || !files.length || files.length>64) return false;
  const names=new Set(); let total=0;
  return files.every(f=>{
    if(!obj(f) || !text(f.name,128) || !/^[A-Za-z0-9_-][A-Za-z0-9_. -]*$/.test(f.name) || f.name.includes('..')) return false;
    const name=f.name.toLowerCase();
    if(names.has(name) || !['yft','ytd','ydr'].includes(f.extension) || !name.endsWith('.'+f.extension)) return false;
    names.add(name);total+=f.size;
    return int(f.size) && f.size<=268435456 && total<=1073741824 && url(f.url) && typeof f.sha256==='string' && /^[a-f0-9]{64}$/.test(f.sha256);
  });
}
function validArchive(m) {
 const remote='archiveURL' in m;
 if(!remote || 'bundleArchive' in m)return false;
 if(remote && (!url(m.archiveURL) || !/\.zip(?:[?#]|$)/i.test(m.archiveURL)))return false;
 if(!int(m.archiveSize) || m.archiveSize>536870912 || typeof m.archiveSha256!=='string' || !/^[a-f0-9]{64}$/.test(m.archiveSha256))return false;
 return true;
}
function validExpected(m){
 return !('expectedMods' in m) || (Array.isArray(m.expectedMods) && m.expectedMods.length>0 && m.expectedMods.length<=20 && m.expectedMods.every(x=>id(x)));
}
function validMods(c) {
  if(!obj(c) || c.schema!==1 || !Array.isArray(c.categories) || c.categories.length>50 || !c.categories.every(x=>text(x,80)) || !Array.isArray(c.mods) || c.mods.length>2000) return false;
  const ids=new Set();
  return c.mods.every(m=>{
    if(!obj(m) || !id(m.id) || ids.has(m.id.toLowerCase())) return false;
    ids.add(m.id.toLowerCase());
    return text(m.name,150) && m.name.length && text(m.description) && c.categories.includes(m.category) && image(m.image)
      && (validFiles(modFiles(m)) || validArchive(m)) && (!('archiveURL' in m || 'bundleArchive' in m) || validArchive(m))
      && validExpected(m) && int(m.minKit) && int(m.maxKit)
      && m.maxKit>=m.minKit && text(m.compatibility,250);
  });
}
function mode(c,version,now) {
  // AMAR YT: remote update notices must never prevent local play.
  const u=c && c.update;
  if(!u || !u.enabled) return '';
  return version<u.latest ? 'optional' : '';
}

// Serialize across the JSCore boundary so booleans and arrays use JSON semantics.
function acceptsJSON(raw, mods) {
  try { const value=JSON.parse(raw); return !!(mods ? validMods(value) : validConfig(value)); }
  catch (_) { return false; }
}
