# ApexCare Engine (pcLapfix) 🚀
**أداة الصيانة الذاتية والفحص الشامل، وتحديث التعريفات وإصلاح نظام ويندوز**

ApexCare Engine هي أداة متطورة ومكتوبة بلغة PowerShell؛ صُممت لتعمل كأداة تشخيص، وتحديث، وإصلاح وصيانة ذاتية متقدمة لأجهزة الويندوز، وتدعم استكمال العمليات تلقائياً بعد إعادة التشغيل (Reboot Survival).

---

## ⚡ التشغيل الفوري بسطر واحد (Quick Run)
يمكنك تشغيل الأداة مباشرة بأي من الرابطين التاليين (المختصر أو الأصلي) عبر فتح **PowerShell كمسؤول (Run as Administrator)**:

### 1. الرابط السريع المختصر (الأسهل للحفظ والكتابة):
```powershell
irm tinyurl.com/pclabfix | iex
```

### 2. الرابط الأصلي المباشر من GitHub:
```powershell
irm https://raw.githubusercontent.com/yousefmasterhr-lab/pclabfix/main/ApexCare.ps1 | iex
```

---

## 🌟 الميزات الرئيسية (Key Features)

1. **التعرف التلقائي على الشركة المصنعة وتوليد الروابط الرسمية (OEM Support Hub)**:
   - التعرف على الشركة المصنعة والموديل ورقم السيريال (Serial Number / Service Tag).
   - توفير رابط مباشر لصفحة تحميل أداة التشخيص الرسمية المعتمدة وصفحة التعريفات الخاصة بجهازك:
     - **Dell**: Dell SupportAssist / Dell Command Update & Service Tag Portal.
     - **HP**: HP Support Assistant & Official Driver Portal.
     - **Lenovo**: Lenovo System Update & Lenovo Vantage.
     - **Acer**: Acer Care Center & Driver Support Portal.
     - **ASUS**: MyASUS & ASUS Download Center.
     - **MSI**: MSI Center / Dragon Center.
     - **Gigabyte**: GIGABYTE Control Center (GCC).
     - **Samsung / Huawei / Surface**: أدوات الدعم الرسمية لكل منصة.
     - **Custom PC / تجميعات**: التعرف على المعالج (Intel DSA للأجهزة المعتمدة على إنتل / AMD Auto-Detect لأجهزة AMD).
   - إمكانية فتح رابط أداة الفحص الرسمية في المتصفح مباشرة بنقرة زر واحدة.

2. **فحص مواصفات الجهاز وتآكل البطارية (Hardware & Battery Audit)**:
   - تمييز نوع الجهاز تلقائياً (Laptop أم Desktop).
   - للأجهزة المحمولة: فحص نسبة تآكل البطارية الفعلي (Battery Wear Level) بدقة وحساب سعة التصميم مقابل السعة الحالية.
   - فحص صحة الأقراص الصلبة ووسائط التخزين (Health Status).

3. **الصيانة والتنظيف العميق (Deep Cleanup & Optimization)**:
   - تنظيف مجلدات الكاش والملفات المؤقتة (Temp, Prefetch, Thumbnails, SoftwareDistribution).
   - تفريغ كاش DNS وإجراء تحسين TRIM لوحدات التخزين من نوع SSD لزيادة سرعة الأداء.

4. **فحص وإصلاح ملفات نظام ويندوز (OS Repair)**:
   - تنفيذ DISM (`/Cleanup-Image /RestoreHealth`) لإصلاح مستودع مكونات النظام.
   - تشغيل فحص SFC (`/scannow`) لمعالجة أي ملفات تالفة بالنظام.

5. **تحديث التعريفات والبرامج**:
   - تثبيت التعريفات المعلقة والملحقات مباشرة من كتالوج تحديثات مايكروسوفت عبر PSWindowsUpdate.
   - ترقية جميع البرامج المثبتة على الجهاز إلى أحدث إصداراتها الرسمية بنقرة واحدة عبر Winget.

6. **نظام استمرار العمل بعد إعادة التشغيل (Reboot Survival)**:
   - في حال طلبت التحديثات إعادة تشغيل إجبارية للنظام، تسجل الأداة حالتها عبر مفتاح Registry `RunOnce` وتستأنف العمل تلقائياً من المرحلة التالية بعد تسجيل الدخول دون فقدان التقدم.

---

## 🛠️ تحويل السكريبت إلى ملف تنفيذي (.exe)

لتحويل السكريبت إلى ملف `.exe` يطلب صلاحيات الأدمن تلقائياً ويعمل بنقرة واحدة:

```powershell
# 1. تثبيت حزمة التحويل (مرة واحدة فقط)
Install-Module -Name ps2exe -Scope CurrentUser -Force

# 2. التحويل إلى ملف ApexCare.exe
Invoke-PS2EXE -InputFile ".\ApexCare.ps1" -OutputFile ".\ApexCare.exe" -RequireAdmin -Title "ApexCare Autonomous Engine" -Description "Unified System Maintenance and Diagnostic Tool" -NoConsole:$false
```

---

## 📋 المتطلبات (Requirements)
- نظام تشغيل: **Windows 10 / Windows 11 / Windows Server**
- صلاحيات: **Administrator**
- PowerShell 5.1 أو أحدث (مدمج افتراضياً في الويندوز)
