# 測試金鑰

這些金鑰是測試專用，勿用於任何環境。

重產方式：先把下面的腳本存成 repo 外的 `pem2jwk.py`（例如放在 `$TMPDIR`，不要提交進 repo），再執行後面的指令，把產出的四個檔案放回這個目錄。

```python
# pem2jwk.py <pem> <kid>  → 印出 RSA 私鑰 JWK
import base64, json, re, subprocess, sys
pem, kid = sys.argv[1], sys.argv[2]
text = subprocess.run(["openssl", "rsa", "-in", pem, "-noout", "-text"], check=True, capture_output=True, text=True).stdout
def field(name):
    m = re.search(rf"^{name}:\s*\n((?:\s+[0-9a-f:]+\n)+)", text, re.M)
    return bytes.fromhex(re.sub(r"[\s:]", "", m.group(1))).lstrip(b"\x00")
def b64(b): return base64.urlsafe_b64encode(b).rstrip(b"=").decode()
e = int(re.search(r"publicExponent: (\d+)", text).group(1))
print(json.dumps({"kty": "RSA", "kid": kid, "n": b64(field("modulus")), "e": b64(e.to_bytes((e.bit_length() + 7) // 8, "big")),
    "d": b64(field("privateExponent")), "p": b64(field("prime1")), "q": b64(field("prime2")),
    "dp": b64(field("exponent1")), "dq": b64(field("exponent2")), "qi": b64(field("coefficient"))}, indent=2))
```

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out rsa-2048.pem
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:1024 -out rsa-1024.pem
python3 -I pem2jwk.py rsa-2048.pem test-2048 > rsa-2048.jwk.json
python3 -I pem2jwk.py rsa-1024.pem test-1024 > rsa-1024.jwk.json
```

預期：兩個 `.jwk.json` 的 `kty` 是 `RSA`、`e` 是 `AQAB`。
