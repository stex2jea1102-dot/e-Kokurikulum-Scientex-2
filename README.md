# STEX2 e-Kokurikulum

Web app / PWA untuk pengurusan kokurikulum SMK Taman Scientex 2 (JEA1102).

## Stack
- Frontend: HTML + CSS + Vanilla JavaScript
- Database/Auth/Storage: Supabase
- Version control: GitHub
- Hosting: Netlify
- PDF: html2pdf.js
- PWA: Web App Manifest + Service Worker

## Setup
1. Cipta projek Supabase.
2. Buka SQL Editor → jalankan `sql/supabase-schema.sql`.
3. Dalam Authentication → Users, cipta akaun guru pertama (email + password). Tambah akaun guru lain bila perlu.
4. Salin Project URL dan Publishable/Anon Key dari Supabase.
5. Isi kedua-dua nilai itu dalam `config.js`.
6. Upload repository ini ke GitHub.
7. Sambungkan repository ke Netlify dan deploy sebagai static site. Tiada build command diperlukan.
8. Buka URL HTTPS Netlify. PWA boleh dipasang ke Home Screen apabila browser menyokong pemasangan PWA.

## Keselamatan
Jangan masukkan `service_role` key ke dalam `config.js`. Hanya guna publishable/anon key dan kekalkan RLS di Supabase.

## Roadmap V2
- Import Excel/CSV untuk master murid/guru.
- Pengurusan ahli setiap unit dan guru penasihat.
- Kehadiran tick-list terus mengikut unit.
- Upload gambar terus ke Supabase Storage.
- OPR dengan 4 foto sebenar dari telefon.
- Dashboard pentadbir dengan status unit: Lengkap / Belum Hantar.
- Analisis kehadiran, PAJSK, pencapaian mengikut murid/unit/tingkatan.
- Export Excel/CSV.
- Backup automatik / eksport berkala.
