# AMAR YT Build 9 — المودات من GitHub فقط

## التغييرات
- ملف `pilot-cars.zip` الذي كان داخل IPA (سايبة `sj131` وبيجو `405glxfnt` وتشارجر `srtday20`) لم يعد جزءًا من التطبيق.
- ملف `source/local-mods.json` قائمة احتياطية **فارغة**؛ ليس مصدر مودات.
- مكتبة `AMARYTKit` لا تضيف السيارات محليًا ولا تبحث عن أرشيف مدمج؛ تعرض القائمة المحفوظة أو المنشورة في `mods.json` عبر HTTPS فقط.
- نظام تنزيل ZIP ثم تسليمه إلى مستورد اللعبة الأصلي باقٍ؛ المودات المثبتة سابقًا في Documents لا تتأثر عند تحديث التطبيق مع الحفاظ على بياناته.
- واجهة `source/panel.html` مصلحة من تعارض اسم الدالة `top` مع `Window.top`.
- زر `PLAY`، ملف `GTA5`، `GTAVArabic.dylib`، و`libgtacompat.dylib` لم تُعدّل لأجل هذه المهمة.

## كيف تضيف مودًا بنفسك دون تعديل IPA

1. ارفع ملف ZIP المتوافق إلى [GitHub Releases](https://github.com/Amaryt1/PROOOOO/releases) في مستودعك أو إلى مصدر HTTPS موثوق.
2. احسب حجم الملف **بالبايت** وSHA-256 للملف نفسه، وارفع صورة المود المصرح باستخدامها إلى `images/mods/`.
3. افتح [mods.json](https://github.com/Amaryt1/PROOOOO/blob/main/mods.json) وأضف عنصرًا ضمن مصفوفة `mods`، وأبقِ `schema: 1`.
4. استخدم مثلاً البنية التالية مع **استبدال القيم الوهمية بأرقام وبصمة وروابط حقيقية**:

```json
{
  "id": "my-car",
  "name": "اسم السيارة",
  "description": "سيارة جديدة",
  "category": "السيارات",
  "image": "https://raw.githubusercontent.com/Amaryt1/PROOOOO/main/images/mods/my-car.jpg",
  "minKit": 5,
  "maxKit": 5,
  "compatibility": "متوافق مع المستورد الأصلي عند صحة بنية ZIP",
  "archiveURL": "https://github.com/Amaryt1/PROOOOO/releases/download/my-tag/my-car.zip",
  "archiveSize": 12000000,
  "archiveSha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "version": "1.0",
  "featured": false
}
```

5. احفظ الملف، افتح قسم المودات واضغط تحديث القائمة. لن تحتاج إلى إصدار IPA جديدة لكل مود إذا كان من الصيغ المدعومة فعلًا.

## تنبيهات
- لا تغيّر بنية ZIP عشوائيًا؛ حزمة السيارات الثلاث السابقة **نجحت في الاستيراد اليدوي** لأنها احتوت على ملفات DLC ببنية قبلها المستورد، لكن هذا لا يعني أن أي ZIP سينجح.
- يمكن إضافة `expectedMods: ["name1"]` فقط عندما يكون اسم مجلد المود النهائي مؤكدًا. عند عدم معرفته لا تُظهر «تم التثبيت» من غير تحقق.
- عدم الاتصال بالإنترنت قد يعرض بيانات مخزنة من آخر تحميل ناجح؛ هذا لا يعني وجود ملفات مود داخل IPA.
- لا تحذف مجلد `GTA V/GTAV/mods` الموجود على الآيباد عند استبدال IPA؛ يخص مودات المستخدم، وليس حجم التطبيق.
- يجب توقيع IPA والمكتبات من جديد بصورة صحيحة قبل تثبيتها على iOS.

### اختبارات المطور
- Workflow: `Build AMARYTKit iOS library`
- Workflow: `Validate published mod catalog`
- فحص JavaScript: منع إعادة تعريف `Window.top`
- فحص APK/IPA: عدم وجود `Payload/GTAV.app/AMARYTKit/pilot-cars.zip` أو أي مودات تجريبية محلية.
