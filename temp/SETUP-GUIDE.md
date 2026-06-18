# Setup Guide: Lab 2.1 (ESO) & Lab 2.2 (Trivy + Cosign)

## Lab 2.2: Trivy Scan + Cosign Signature

### Mục tiêu
- **Trivy**: Scan image → fail nếu CVE HIGH/CRITICAL
- **Cosign**: Ký image sau build
- **Policy Controller**: Admission webhook verify signature

### Phase 1: Generate Cosign Keypair (LOCAL)

```bash
# 1. Tạo keypair local
cd ~/gitops/labw10  # hoặc d:\gitOps\labw10 trên Windows
cosign generate-key-pair

# Output:
# - cosign.key (PRIVATE - chứa trong cosign.key)
# - cosign.pub (PUBLIC - chứa key data)
```

**Ghi chú**: 
- Nhập password khi được yêu cầu (ví dụ: `Lab2.2Pass!`)
- **Lưu password này** → cần cho GitHub Secrets

### Phase 2: Add GitHub Secrets

Vào GitHub repo settings:

```
Settings → Secrets and variables → Actions → New repository secret
```

Thêm 2 secrets:

| Secret Name | Value |
|---|---|
| `COSIGN_PRIVATE_KEY` | Nội dung file `cosign.key` |
| `COSIGN_PASSWORD` | Password từ Phase 1 |

### Phase 3: Configure Local Files

#### 3a. Commit cosign.pub

```bash
# File cosign.pub đã được tạo ở bước 1
# Copy vào signing/
cp cosign.pub signing/cosign.pub

# Commit
git add signing/cosign.pub
git commit -m "chore: add cosign public key"
git push
```

#### 3b. Update cluster-image-policy.yaml

Workflow CI sẽ tự động update, nhưng bạn có thể xem preview:

```bash
# Xem cosign.pub
cat signing/cosign.pub

# Dán vào temp/policies/cluster-image-policy.yaml
# Thay thế "REPLACE_WITH_COSIGN_PUBLIC_KEY"
```

**Hoặc**: Chạy workflow lần đầu → CI tự động update

#### 3c. Update namespace label

Workflow CI sẽ auto-add label:
```yaml
metadata:
  name: demo
  labels:
    policy.sigstore.dev/include: "true"
```

**Chú ý**: Gắn label **SAU** khi image đã ký (không sớm hơn)

### Phase 4: Verify ArgoCD Apps

Kiểm tra 2 app đã trong `temp/argocd/apps/`:

✅ **policy-controller.yaml** - Cài Sigstore Policy Controller
✅ **policies.yaml** - Sync ClusterImagePolicy

Nếu dùng root app, cả 2 sẽ auto-sync.

### Phase 5: Test 3 Scenarios

#### Test 1: Push image CVE HIGH → CI RED

```bash
# Tạo image có CVE (ví dụ: dùng base image cũ)
cd temp/src/api
# ... sửa Dockerfile để dùng base cũ ...
git push

# Kỳ vọng: GitHub Actions RED (Trivy fail)
```

#### Test 2: Deploy unsigned image → Admission REJECT

```bash
# Kiểm tra namespace có label không
kubectl get ns demo --show-labels

# Deploy unsigned image test
kubectl apply -f temp/policy-tests/unsigned-image-deployment.yaml

# Kỳ vọng: admission webhook deny
# Error: admission webhook "policy.sigstore.dev" denied the request
```

#### Test 3: Deploy signed image → PASS

```bash
# Nếu CI OK (image đã scan + ký):
kubectl get rollout api -n demo

# Kỳ vọng: pods running, không restart
```

---

## Lab 2.1: ESO (External Secrets Operator)

### Mục tiêu
- Secret từ AWS → K8s Secret (auto-sync)
- Pod không restart (AGE không đổi)
- Repo sạch (không hardcode secret)

### Setup ESO

#### 1. Install ESO + AWS Provider

```bash
kubectl apply -f temp/argocd/apps/eso.yaml
# Hoặc manual:
# helm repo add external-secrets https://charts.external-secrets.io
# helm install external-secrets external-secrets/external-secrets
```

#### 2. Configure AWS SecretStore

```bash
# File: temp/eso/secret-store.yaml
# Cần AWS credentials (IAM role hoặc key)

# Nếu dùng IAM role (recommended):
# - EKS IRSA setup (link SA with AWS role)
# - Role có permission: secretsmanager:GetSecretValue

# Nếu dùng AWS key:
# kubectl create secret generic aws-secret \
#   --from-literal=access-key=AKIAIOSFODNN7EXAMPLE \
#   --from-literal=secret-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

#### 3. Create ExternalSecret

```yaml
# temp/eso/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-secret
  namespace: demo
spec:
  refreshInterval: 30s  # ← Sync mỗi 30s
  secretStoreRef:
    name: aws-secret-store
    kind: SecretStore
  target:
    name: db-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: lab2.1/db-password  # AWS Secrets Manager key
```

#### 4. Verify Sync

```bash
# Check ESO pod
kubectl get pods -n external-secrets-system

# Check secret tự động tạo
kubectl get secret db-secret -n demo -o jsonpath='{.data.password}' | base64 -d

# Check pod AGE không đổi
kubectl get pods -n demo -w

# Change AWS secret value
# aws secretsmanager update-secret --secret-id lab2.1/db-password --secret-string "new-password"

# Verify K8s secret updated trong < 60s
# kubectl get secret db-secret -n demo -w
```

#### 5. Cleanup: Remove Password dari Repo

```bash
# Tìm password hardcode
grep -ri "password" .
grep -ri "secret" .
grep -ri "credential" .

# Xóa tất cả credentials:
# - app-alert/email-secret.yaml (nếu có)
# - Any .env files
# - Any hardcoded credentials

# Commit
git add -A
git commit -m "chore: remove hardcoded secrets"
git push
```

---

## Checklist: Nghiệm Thu

### Lab 2.2 (Trivy + Cosign)

- [ ] Cosign keypair tạo xong
- [ ] `COSIGN_PRIVATE_KEY` & `COSIGN_PASSWORD` trong GitHub Secrets
- [ ] `cosign.pub` committed → `signing/cosign.pub`
- [ ] `cluster-image-policy.yaml` có public key
- [ ] `policy-controller.yaml` deployed
- [ ] `policies.yaml` deployed (ClusterImagePolicy)
- [ ] Namespace `demo` có label `policy.sigstore.dev/include: "true"`
- [ ] Test 1: CVE image → CI RED ✓
- [ ] Test 2: Unsigned image → Admission REJECT ✓
- [ ] Test 3: Signed image → PASS ✓

### Lab 2.1 (ESO)

- [ ] ESO operator cài xong
- [ ] SecretStore connected to AWS
- [ ] ExternalSecret synced (pod không restart)
- [ ] Secret value tự cập nhật < 60s ✓
- [ ] Pod AGE không đổi ✓
- [ ] Repo sạch (no hardcoded secrets) ✓

---

## Troubleshooting

### Cosign
- "passwords do not match" → Enter same password twice
- "private key not found" → Check file permissions, cosign.key phải accessible

### Trivy
- "CVE not found" → Update Trivy DB: `trivy image --download-db-only`
- "exit code 1" expected → Nghĩa là có CVE (đây là thành công của test)

### Policy Controller
- "admission webhook not ready" → Wait for pod startup
- "policy.sigstore.dev/include label missing" → Label không gắn hoặc sai namespace

### ESO
- "secret not syncing" → Check SecretStore credentials, AWS permissions
- "connection timeout" → Check VPC/Network access to AWS

---

## References

- Cosign: https://docs.sigstore.dev/cosign/
- Sigstore Policy Controller: https://docs.sigstore.dev/policy-controller/
- External Secrets: https://external-secrets.io/
- Trivy: https://aquasecurity.github.io/trivy/

