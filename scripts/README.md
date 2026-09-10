\# Knowledge card importer



Importer, JSON kartlarını doğrular ve `searchTokens` üretir. Varsayılan çalışma modu

\*\*dry-run\*\*'dır; bu mod Firebase Admin SDK'yı yüklemez veya başlatmaz.



```bash

node scripts/import\_knowledge.js data/cards.json

node scripts/import\_knowledge.js data/cards.json --dry-run

```



Kontrollü bir test için `--only`, virgülle ayrılmış belge ID'leriyle yalnızca seçilen

kartları işler. Boşluklar temizlenir, tekrarlanan ID'ler bir kez kullanılır ve JSON'da

bulunmayan bir ID varsa işlem Firebase başlatılmadan durdurulur:



```bash

node scripts/import\_knowledge.js data/cards.json --only fish\_001,fish\_002,fish\_003 --dry-run

```



Yalnızca bilinçli bir canlı aktarım için `--commit` kullanılmalıdır:



```bash

GOOGLE\_APPLICATION\_CREDENTIALS=/path/to/service-account.json \\

&#x20; node scripts/import\_knowledge.js data/cards.json --commit

```



Aynı filtre gerektiğinde commit modunda da kullanılabilir:



```bash

GOOGLE\_APPLICATION\_CREDENTIALS=/path/to/service-account.json \\

&#x20; node scripts/import\_knowledge.js data/cards.json --only fish\_001,fish\_002,fish\_003 --commit

```



Commit modu `knowledge\_cards` koleksiyonundaki mevcut belge ID'lerini atlar ve yeni

belgeleri Firestore sınırının altında kalan 450 belgeli batch'lerle `batch.create`

kullanarak oluşturur. Belge ID'si kartın `id` alanıdır; mevcut belgeler değiştirilmez.

Yeni belgelerde `createdAt` ve `olusturulmaTarihi` sunucu zaman damgası olarak yazılır.



Service account anahtarını repository'ye koymayın. Importer commit modunda Application

Default Credentials kullanır; anahtar gerekiyorsa repository dışındaki dosyayı

`GOOGLE\_APPLICATION\_CREDENTIALS` ile gösterin.



