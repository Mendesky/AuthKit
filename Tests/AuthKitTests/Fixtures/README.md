# 測試金鑰

這些金鑰是測試專用,勿用於任何環境。

重產方式(腳本 `pem2jwk.py` 不進 repo,見 AccessTokenSigner 計畫 Task 1):

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out rsa-2048.pem
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:1024 -out rsa-1024.pem
python3 -I pem2jwk.py rsa-2048.pem test-2048 > rsa-2048.jwk.json
python3 -I pem2jwk.py rsa-1024.pem test-1024 > rsa-1024.jwk.json
```
