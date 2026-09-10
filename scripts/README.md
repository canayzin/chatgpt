# Knowledge card importer

Importer, verilen JSON array'ini doğrular ve varsayılan olarak yalnızca güvenli bir önizleme yapar:

```sh
npm run content:check -- data/ai_learn_do_fish_drink_water_240_benzersiz_kart.json --dry-run
```

`--dry-run` yazılmasa da varsayılan davranıştır; Firebase bağlantısı kurulmaz ve veri yazılmaz. Gerçek aktarım yalnızca açıkça `--commit` verilince yapılır. Commit modu Application Default Credentials kullanır, mevcut doküman kimliklerini atlar ve yazmaları 450'lik batch'lere böler:

```sh
GOOGLE_APPLICATION_CREDENTIALS=/repo/disinda/service-account.json npm run content:check -- data/baska_kitap.json --commit
```

Service account ve private key dosyalarını repository içine koymayın. Commit çalıştırmadan önce doğru Firebase projesinin seçildiğini ayrıca doğrulayın.
