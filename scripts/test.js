'use strict';
const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert/strict');
process.chdir(path.resolve(__dirname,'..'));
const ctx=vm.createContext({});vm.runInContext(fs.readFileSync('source/policy.js','utf8'),ctx);
const c=JSON.parse(fs.readFileSync('config.json')),mods=JSON.parse(fs.readFileSync('mods.json'));
assert(ctx.validConfig(c));assert(ctx.validMods(mods));
const now=Date.UTC(2026,10,22),copy=x=>JSON.parse(JSON.stringify(x));
const u=copy(c);Object.assign(u.update,{enabled:true,minimum:6,latest:7,expiresUTC:new Date(now+3600000).toISOString()});
assert(ctx.validConfig(u));assert.equal(ctx.mode(u,5,now),'force');assert.equal(ctx.mode(u,6,now),'optional');assert.equal(ctx.mode(u,7,now),'');
assert.equal(ctx.mode(u,5,now+3600001),'optional');assert.equal(ctx.mode(c,5,now),'');
u.update.expiresUTC=new Date(now+8*86400000).toISOString();assert.notEqual(ctx.mode(u,5,now),'force');
for(const bad of [null,{},[],{...c,update:{}},{...c,modsURL:'file:///bad'},{...c,welcome:{...c.welcome,enabled:'true'}},{...c,notification:{...c.notification,contactURL:'javascript:bad()'}}])assert(!ctx.validConfig(bad));
const m={id:'car',name:'سيارة',category:mods.categories[0],description:'',image:'',size:64,sha256:'a'.repeat(64),url:'https://example.com/test.yft',extension:'yft',minKit:5,maxKit:5,compatibility:'V5'};
const catalog=(...items)=>({...mods,mods:items});
assert(ctx.validMods(catalog(m)));assert(!ctx.validMods(catalog(m,m)));
for(const fields of [{id:'../car'},{size:0},{size:268435457},{sha256:'n/a'},{url:'http://example.com/x'},{extension:'dylib'},{extension:'zip'},{minKit:6,maxKit:5}])assert(!ctx.validMods(catalog({...m,...fields})));
assert.throws(()=>JSON.parse('{"broken":'));console.log('Configuration, fallback inputs, update thresholds, expiry and mod policy passed.');
const files=['car.yft','car_hi.yft','car.ytd'].map(name=>({name,url:m.url,size:64,sha256:m.sha256,extension:name.split('.').pop()}));
assert(ctx.validMods(catalog({...m,files})));assert(ctx.acceptsJSON(JSON.stringify(c),false));assert(!ctx.acceptsJSON('null',false));
for(const name of ['../car.yft','a/b.yft','car.dylib','.car.yft','car.yft\u0000'])assert(!ctx.validMods(catalog({...m,files:[{...files[0],name}]})));
assert(!ctx.validMods(catalog({...m,files:[]})));assert(!ctx.validMods(catalog({...m,files:[files[0],{...files[0],name:'CAR.YFT'}]})));
console.log('Multi-file manifests, legacy entries, duplicates, unsafe names and JSON bridge passed.');


const build9=JSON.parse(fs.readFileSync('source/local-mods.json','utf8'));
assert(ctx.validMods(build9),'Empty offline fallback must validate');
assert.equal(build9.mods.length,0,'No vehicle resources may be bundled');
const archiveTest={...m,archiveURL:'https://example.com/car.zip',archiveSize:123456,archiveSha256:'c'.repeat(64),expectedMods:['safe-car']};
assert(ctx.validMods(catalog(archiveTest)));
for(const bad of [
 {...archiveTest,archiveURL:'http://example.com/car.zip'},
 {...archiveTest,archiveURL:'https://example.com/car.dylib'},
 {...archiveTest,archiveSize:0},
 {...archiveTest,archiveSize:536870913},
 {...archiveTest,archiveSha256:'bad'},
 {...archiveTest,expectedMods:['../GTAV']},
 {...archiveTest,expectedMods:['a/b']}
 ])assert(!ctx.validMods(catalog(bad)),'Reject unsafe ZIP metadata');
assert(!ctx.validMods(catalog({...archiveTest,bundleArchive:'pilot-cars.zip'})));
const panel=fs.readFileSync('source/panel.html','utf8');
assert(panel.includes("post('download',m.id)"));
assert(panel.includes("post('cancelDownload')"));
assert(!panel.includes('متصل بـ GitHub'));
assert(!panel.includes('AMAR YT Kit Active'));
const native=fs.readFileSync('source/AMARYTKit.m','utf8');
assert(native.includes('NSSelectorFromString(@"importModsFrom:")'));
assert(native.includes('installedFolders(self.pendingInstallDirs)'));
assert(!native.includes('AMAR YT Kit Active · Build 8'));
console.log('Build9 ZIP validation, bundle resources, native-import bridge and clean UI checks passed.');

const markupScript=panel.match(/<script>([\s\S]*?)<\/script>/);
assert(markupScript,'Store JavaScript must be embedded');
const browserGlobals={console};
Object.defineProperty(browserGlobals,'top',{value:{},writable:false,configurable:false});
const browserVM=vm.createContext(browserGlobals);
vm.runInContext(markupScript[1],browserVM,{filename:'panel.html'});
assert.equal(vm.runInContext('typeof render',browserVM),'function');
console.log('Catalog JavaScript initializes even with reserved window.top (Build9 hotfix).');

assert(!native.includes('catalogWithPilot'), 'No bundled-pilot injection');
assert(!native.includes('pilot-cars.zip'), 'No bundled vehicle data references');
assert(!panel.includes('function top('), 'Reserved Window.top global collision must remain fixed');
console.log('Remote-only catalog, clean UI and native ZIP integration verified.');
