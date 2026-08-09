---
name: MiningHub UI integration
description: Durable guidance for keeping the MiningHub and TemplateGUI runtimes compatible.
---

TemplateGUI harus dimuat sebagai stack modul lengkap sebelum tab MiningHub dibuat. Tab MiningHub memakai adapter karena builder TemplateGUI menerima parent Frame dan mengembalikan API `SetValue`, sedangkan tab lama memakai object-style Rayfield dengan `Set`, `Refresh`, dan paragraph `Set`.

**Why:** Mengganti hanya loader atau theme tidak cukup; kontrak parent dan callback UI berbeda, sehingga fitur farm dapat gagal walaupun tampilan utama muncul.

**How to apply:** Pertahankan namespace visual `XiFilTemplateGUI_*` terpisah dari `MiningHub`, muat adapter setelah stack TemplateGUI, dan hindari benturan listener tombol `F` ketika TemplateGUI memakai mode `Keybind [F]`.