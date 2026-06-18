# Lab 2.1: ESO Secret Rotation - Detailed Setup

## Bước 1: Tạo AWS Secret

Trong AWS Secrets Manager (region: `ap-southeast-1`):

```bash
# Dùng AWS CLI
aws secretsmanager create-secret \
  --name labw10/api/db \
  --secret-string '{"password":"initial-password-123"}' \
  --region ap-southeast-1

# Hoặc update nếu đã tồn tại:
aws secretsmanager update-secret \
  --secret-id labw10/api/db \
  --secret-string '{"password":"initial-password-123"}' \
  --region ap-southeast-1
```

## Bước 2: Setup AWS Credentials trong K8s

```bash
# Tạo K8s Secret với AWS credentials
# ⚠️ CHỈ dùng cho lab, không production
kubectl -n demo create secret generic aws-secret-manager-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY"

# Hoặc nếu dùng IAM Role (recommended):
# Attach policy: SecretsManagerReadWrite
# Link service account with IRSA (EKS only)
```

## Bước 3: Deploy ESO + SecretStore + ExternalSecret

```bash
# 1. ESO operator đã trong argocd/apps/eso.yaml
# ArgoCD sẽ auto-install

# 2. Wait for ESO pods
kubectl -n external-secrets wait --for=condition=available \
  --timeout=300s deployment/external-secrets

# 3. Deploy SecretStore
kubectl apply -f temp/eso/secret-store.yaml

# 4. Deploy ExternalSecret
kubectl apply -f temp/eso/external-secret.yaml

# 5. Verify sync
kubectl -n demo get externalsecret api-db-credentials
kubectl -n demo get secret api-db-credentials -o jsonpath='{.data.password}' | base64 -d
```

## Bước 4: Verify Secret Rotation (< 60s)

### Test 4a: Change secret in AWS

```bash
# Thay đổi giá trị trong AWS
aws secretsmanager update-secret \
  --secret-id labw10/api/db \
  --secret-string '{"password":"updated-password-xyz"}' \
  --region ap-southeast-1

# Theo dõi K8s Secret tự cập nhật
watch kubectl -n demo get secret api-db-credentials -o jsonpath='{.data.password}' | base64 -d

# Kỳ vọng: Thay đổi trong < 30s (refreshInterval)
```

### Test 4b: Verify pod AGE không đổi

```bash
# Terminal 1: Watch pods
kubectl -n demo get pods -w

# Terminal 2: Thay đổi AWS secret
aws secretsmanager update-secret \
  --secret-id labw10/api/db \
  --secret-string '{"password":"third-password-abc"}' \
  --region ap-southeast-1

# Kỳ vọng: Pods không restart, AGE không reset
```

## Bước 5: Verify Repo Clean (No Hardcoded Secrets)

```bash
# Tìm password
grep -ri "password" . --include="*.yaml" --include="*.yml"
grep -ri "secret" . --include="*.yaml" --include="*.yml"
grep -ri "credential" . --include="*.yaml" --include="*.yml"

# Kỳ vọng: Chỉ thấy metadata/mapping, không thấy actual value

# Xem .gitignore
cat .gitignore

# Ghi chú: Credentials phải ở AWS/K8s Secret, không trong repo
```

## Debugging: Nếu Secret không sync

```bash
# 1. Check ESO pods
kubectl -n external-secrets get pods
kubectl -n external-secrets logs -l app.kubernetes.io/name=external-secrets -f

# 2. Check SecretStore status
kubectl -n demo describe secretstore aws-secrets-manager

# 3. Check ExternalSecret status
kubectl -n demo describe externalsecret api-db-credentials

# 4. Common issues:
# - AWS credentials sai → Check K8s Secret
# - IAM permissions → Add SecretsManagerReadWrite policy
# - Secret key sai → Check "labw10/api/db" trong AWS
# - Region sai → Check secret-store.yaml region
```

## Expected Behavior

✅ **S\u1eal thành công (Achieved)**:
1. ExternalSecret created & synced
2. K8s Secret `api-db-credentials` tự động tạo
3. Khi thay đổi AWS Secret → K8s Secret cập nhật < 60s
4. Pod không restart (mount Secret as volume)
5. Repo không chứa hardcoded password

❌ **Thất bại (Should NOT see)**:
- Pod restart/reboots
- Secret value không cập nhật
- Hardcoded password trong repo
- Access denied from K8s to AWS

