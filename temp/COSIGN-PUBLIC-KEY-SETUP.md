## Lab 2.2: Tạo & Deploy Cosign Public Key

### Bước 1: Copy Public Key (Local)

Sau khi chạy `cosign generate-key-pair`, file `cosign.pub` sẽ được tạo.

```bash
# On your local machine (sau khi generate key)
cp cosign.pub temp/signing/cosign.pub

# Verify
cat temp/signing/cosign.pub
# Output sample:
# -----BEGIN PUBLIC KEY-----
# MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
# -----END PUBLIC KEY-----
```

### Bước 2: Update cluster-image-policy.yaml

**Option A: Manual (Nếu key sẵn sàng)**

```bash
# 1. Lấy public key content
PUBLIC_KEY=$(cat temp/signing/cosign.pub)

# 2. Update policy file
# Thay thế REPLACE_WITH_COSIGN_PUBLIC_KEY bằng:
# -----BEGIN PUBLIC KEY-----
# ... key data ...
# -----END PUBLIC KEY-----
```

File mẫu:
```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-signed-images
spec:
  images:
  - glob: "**"
  authorities:
  - key:
      hashAlgorithm: sha256
      data: |
        -----BEGIN PUBLIC KEY-----
        <PASTE_YOUR_PUBLIC_KEY_HERE>
        -----END PUBLIC KEY-----
  mode: enforce
```

**Option B: Auto (CI sẽ update)**

Workflow `.github/workflows/build-push.yml` sẽ tự động:
1. Tạo signing/cosign.pub (nếu chưa có)
2. Dán public key vào cluster-image-policy.yaml
3. Commit lại

### Bước 3: Commit & Push

```bash
git add temp/signing/cosign.pub temp/policies/cluster-image-policy.yaml
git commit -m "chore: add cosign public key for policy"
git push
```

### Bước 4: Verify Policy Deployed

```bash
# Check ClusterImagePolicy applied
kubectl get clusterimagepolicies
kubectl describe clusterimagepolicy require-signed-images

# Output chứa public key:
# authorities[0].key.data: -----BEGIN PUBLIC KEY-----...
```

### Troubleshooting

| Issue | Giải pháp |
|---|---|
| "PUBLIC_KEY is empty" | Chạy `cosign generate-key-pair` lại |
| "cluster-image-policy.yaml no match" | Xem lại file path, phải là `temp/policies/cluster-image-policy.yaml` |
| Policy không enforce | Kiểm tra namespace label `policy.sigstore.dev/include: "true"` |

