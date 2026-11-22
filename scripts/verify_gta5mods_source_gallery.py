#!/usr/bin/env python3
"""Verify public GTA5-Mods source pages and original preview image URLs.
No binary republishing, no ZIP compatibility claims, no live mods.json edits.
"""
import concurrent.futures,html,json,pathlib,re,urllib.request
from html.parser import HTMLParser
from urllib.parse import urljoin,urlparse

BASE="https://www.gta5-mods.com/"
class Page(HTMLParser):
    def __init__(self):
        super().__init__();self.metas={};self.links=[];self.words=[]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=="meta" and a.get("content"):
            self.metas[(a.get("property") or a.get("name") or "").lower()]=a["content"]
        if tag=="link" and a.get("rel")=="canonical":self.metas["canonical"]=a.get("href")
        if tag=="a" and a.get("href"):self.links.append(a["href"])
    def handle_data(self,content):self.words.append(content)

def inspect(x):
    url=x["source_page"]
    if not url.startswith(BASE+"vehicles/"):return None,"invalid domain"
    req=urllib.request.Request(url,headers={"User-Agent":"Mozilla/5.0 (compatible; AMARYT-GTA-Mod-Source-Catalog/1.0)","Accept":"text/html"})
    try:
        with urllib.request.urlopen(req,timeout=20) as f:
            if f.status!=200 or "html" not in f.headers.get("content-type",""):return None,"not HTML 200"
            body=f.read(900000).decode("utf-8","replace")
    except Exception as e:return None,str(e)[:140]
    p=Page()
    try:p.feed(body)
    except Exception as e:return None,"parsing "+str(e)[:90]
    title=html.unescape(p.metas.get("og:title","")).strip()
    image=html.unescape(p.metas.get("og:image","")).strip()
    canonical=p.metas.get("canonical") or url
    if not title or not image or "img.gta5-mods.com" not in image:return None,"missing original title/preview"
    if urlparse(canonical).path.rstrip("/")!=urlparse(url).path.rstrip("/"):return None,"different canonical page"
    link=next((urljoin(BASE,u) for u in p.links if re.fullmatch(r"/vehicles/[^/]+/download/\d+",u)),None)
    bodytext=html.unescape(" ".join(p.words))
    possible=[]
    for regex in (r"dlcpacks:/([a-zA-Z0-9_-]{2,45})/",r"spawn(?:ing)?\s+(?:the\s+)?(?:car\s+)?(?:with\s+)?(?:name|code)\s*[:=\s\"']+([a-zA-Z0-9_-]{2,45})"):
        for m in re.findall(regex,bodytext,re.I):
            if m not in possible:possible.append(m)
    return {
        "name_ar":x["name_ar"],"original_title":title,"source_page":url,
        "original_preview_url":image,"original_download_landing_url":link,
        "possible_spawn_names_not_verified":possible[:4],
        "verified_page_and_image_metadata":True,
        "direct_zip_verified":False,
        "zip_sha256_verified":False,
        "ios_install_tested":False,
        "permission_to_redistribute_confirmed":False,
        "visibility":"research_only"
    },None

seed=json.loads(pathlib.Path("research/iraq-gulf-car-sources-seed.json").read_text())["vehicles"]
results=[];errors=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    work={pool.submit(inspect,x):x for x in seed}
    for f in concurrent.futures.as_completed(work):
        item=work[f]
        try:r,err=f.result()
        except Exception as e:r,err=None,str(e)
        if r:results.append(r)
        else:errors.append({"name_ar":item["name_ar"],"source_page":item["source_page"],"reason":err})
idx={x["source_page"]:i for i,x in enumerate(seed)}
results.sort(key=lambda x:idx[x["source_page"]])
errors.sort(key=lambda x:idx[x["source_page"]])
out=pathlib.Path("research")
data={"schema":1,"checked":len(seed),"verified":len(results),"missing":len(errors),
      "warning_ar":"روابط صفحات وصور فقط. ليست ملفات ZIP صالحة للتثبيت. لا ترفع لملف mods.json قبل فحص أرشيف وصلاحية نشره وتجربة iPad.",
      "vehicles":results,"unverified":errors}
(out/"iraq-gulf-verified-source-gallery.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
rows=[
"# معرض أكثر من 50 سيارة عراقية وخليجية — صور وروابط مودات أصلية",
"",
f"تم التحقق من **{len(results)}** صفحة تحتوي على اسم وصورة من المصدر الأصلي، من أصل {len(seed)} مصدرًا.",
"",
"> **هذه روابط معاينة وبحث فقط، وليست ملفات ZIP قابلة للتثبيت تلقائيًا.** أزرار تحميل موقع GTA5-Mods ترجع أحيانًا صفحة HTML، وليست رابط أرشيف ثابتًا. لم يُفحص الملف أو السماح بإعادة نشره أو عمله على iPad. أبقينا المتجر العام على Iraqi Garage المجربة فقط.",
"",
"| الصورة الأصلية | الاسم بالعربية | اسم المود الأصلي | الروابط | اسم التوليد في وصف المؤلف |",
"|---|---|---|---|---|"
]
for x in results:
    title=x["original_title"].replace("|","—")
    name=x["name_ar"].replace("|","—")
    link="[صفحة المود]("+x["source_page"]+")"
    if x["original_download_landing_url"]:
        link+=" · [زر تحميل الموقع]("+x["original_download_landing_url"]+")"
    spawn=", ".join(x["possible_spawn_names_not_verified"]) or "غير مؤكد"
    rows.append("| <img src='"+x["original_preview_url"]+"' alt='"+name+"' width='125'> | **"+name+"** | "+title+" | "+link+" | "+spawn+" |")
rows+=["","## ملاحظات مهمة",
       "- أسماء المستخدم في متجر AMAR YT عربية، لكن الاسم في القائمة اليمنى الأصلية يحتاج تعديلاً داخل IPA وليس تغيير هوية DLC.",
       "- الصورة تُعرض مباشرة من موقع المطور الأصلي، ولم تُنسخ إلى هذا المستودع.",
       "- تحميل صفحة المود لا يعادل تحميل ZIP. لا يوجد SHA-256 أو حجم بايت معتمد لهذه الملفات حتى الآن.",
       "- لا ترفع ملفات معدلة أو صور مطورين دون تصريح أو ترخيص مناسب.",
       "",
       "## صفحات لم تنجح مطابقتها"]
rows += ["- "+x["name_ar"]+": "+str(x["reason"])+" — "+x["source_page"] for x in errors]
(out/"IRAQI-GULF-50-PHOTOS-AND-SOURCES.md").write_text("\n".join(rows)+"\n")
print(json.dumps({"checked":len(seed),"verified":len(results),"errors":errors},ensure_ascii=False))
if len(results)<50:raise SystemExit("Less than 50 real pages verified; do not claim completion")
