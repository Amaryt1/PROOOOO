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
  if(!obj(c) || c.schema!==1 || !int(c.version) || !url(c.modsURL)) return false;
  if(!obj(c.identity) || !text(c.identity.name,80) || !/^#[a-f\d]{6}$/i.test(c.identity.accent) || !image(c.identity.logo)) return false;
  if(!obj(c.social) || !['telegram','instagram','tiktok'].every(k=>url(c.social[k])) || !obj(c.sections) || !flag(c.sections.mods)) return false;
  if(![c.welcome,c.notification].every(m=>message(m) && id(m.id) && ['once','launch'].includes(m.frequency))) return false;
  const u=c.update;
  return !!(message(u) && int(u.minimum) && int(u.latest) && u.latest>=u.minimum && url(u.url) && text(u.expiresUTC)
    && (u.expiresUTC==='' || (Number.isFinite(Date.parse(u.expiresUTC)) && /Z$/.test(u.expiresUTC)))
    && Array.isArray(u.features) && u.features.length<=25 && u.features.every(x=>text(x,240))
    && Array.isArray(c.news) && c.news.length<=40 && c.news.every(x=>text(x,500)));
}
function validMods(c) {
  if(!obj(c) || c.schema!==1 || !Array.isArray(c.categories) || c.categories.length>50 || !c.categories.every(x=>text(x,80)) || !Array.isArray(c.mods) || c.mods.length>2000) return false;
  const ids=new Set();
  return c.mods.every(m=>{
    if(!obj(m) || !id(m.id) || ids.has(m.id)) return false;
    ids.add(m.id);
    return text(m.name,150) && m.name.length && text(m.description) && c.categories.includes(m.category) && image(m.image)
      && int(m.size) && m.size<=268435456 && typeof m.sha256==='string' && /^[a-f0-9]{64}$/.test(m.sha256)
      && url(m.url) && ['yft','ytd','ydr'].includes(m.extension) && int(m.minKit) && int(m.maxKit)
      && m.maxKit>=m.minKit && text(m.compatibility,250);
  });
}
function mode(c,version,now) {
  const u=c.update, end=Date.parse(u.expiresUTC);
  if(!u.enabled) return '';
  if(version<u.minimum && now<end && end-now<=7*86400000) return 'force';
  return version<u.latest ? 'optional' : '';
}
