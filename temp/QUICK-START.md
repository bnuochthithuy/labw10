# 🎯 Lab 2.1 & 2.2: Master Execution Checklist

## Phase 0: Pre-flight Check

```bash
cd d:\gitOps\labw10

# Verify key tools
cosign version    # Should output cosign version
trivy version     # Should output trivy version  
kubectl version   # Should connect to cluster
git status        # Should be in git repo
```

✅ **Tools ready?** Continue to Phase 1.

---

## Phase 1: Generate Cosign Keypair (LOCAL)

### 1.1 Generate Key

```bash
cd d:\gitOps\labw10

# Run this command
C:/Users/User/tools/cosign.exe generate-key-pair

# You will be prompted:
# Enter password for private key: [TYPE_PASSWORD_HERE]
# Enter password for private key again: [REPEAT_SAME_PASSWORD]

# Files created:
# - cosign.key (PRIVATE)
# - cosign.pub (PUBLIC)
```

🔐 **Save the password** - you'll need it for GitHub Secrets.

### 1.2 Add GitHub Secrets

Go to your GitHub repo:
```
Settings → Secrets and variables → Actions → New repository secret
```

Create these 2 secrets:

| Name | Value |
|---|---|
| `COSIGN_PRIVATE_KEY` | Contents of `cosign.key` file |
| `COSIGN_PASSWORD` | Password from step 1.1 |

### 1.3 Commit cosign.pub

```bash
# Copy public key to repo
cp cosign.pub temp/signing/cosign.pub

# Commit
git add .gitignore temp/signing/cosign.pub
git commit -m "chore: add cosign public key for signing"
git push
```

✅ **Phase 1 complete**.

---

## Phase 2: Deploy ESO (Lab 2.1 Prerequisite)

### 2.1 Create AWS Secret

```bash
# In AWS Secrets Manager (region: ap-southeast-1)
aws secretsmanager create-secret \
  --name labw10/api/db \
  --secret-string '{"password":"init-pass-123"}' \
  --region ap-southeast-1

# Or update if exists:
aws secretsmanager update-secret \
  --secret-id labw10/api/db \
  --secret-string '{"password":"init-pass-123"}' \
  --region ap-southeast-1
```

### 2.2 Create K8s AWS Credentials

```bash
# Create secret with AWS credentials
kubectl -n demo create secret generic aws-secret-manager-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY"

# Verify
kubectl -n demo get secret aws-secret-manager-credentials
```

### 2.3 Deploy ESO Stack

```bash
# ESO operator (via ArgoCD) - check it's deployed
kubectl -n external-secrets get pods

# Deploy SecretStore
kubectl apply -f temp/eso/secret-store.yaml

# Deploy ExternalSecret  
kubectl apply -f temp/eso/external-secret.yaml

# Verify sync
kubectl -n demo get externalsecret api-db-credentials
# Should show: STATUS=synced
```

✅ **Phase 2 complete** - ESO ready for Lab 2.1 tests.

---

## Phase 3: Build & Sign Image (Lab 2.2 CI Run)

### 3.1 Trigger CI with Clean Code

```bash
# Make sure Dockerfile has non-vulnerable base image
cat temp/src/api/Dockerfile
# FROM python:3.13-slim  ← Should be recent, not python:3.8

# Push to trigger GitHub Actions
git add temp/src/api/
git commit -m "feat: add api service"
git push
```

### 3.2 Wait for CI to Complete

Go to GitHub repo → **Actions** tab.

Workflow should:
1. ✅ Build image
2. ✅ Trivy scan (0 HIGH/CRITICAL)
3. ✅ Push to GHCR
4. ✅ Sign with Cosign
5. ✅ Update manifests
6. ✅ Commit & push

**If any step fails**, check workflow logs and fix accordingly.

### 3.3 Verify Artifacts

```bash
# Check image pushed
docker pull ghcr.io/bnuochthithuy/w10-api:$(git rev-parse --short HEAD)

# Check public key updated
cat temp/signing/cosign.pub
# Should NOT have "PLACEHOLDER" anymore

# Check policy updated
cat temp/policies/cluster-image-policy.yaml
# Should contain your actual public key

# Check namespace labeled (AFTER image signed)
kubectl get ns demo -o yaml
# Should have: policy.sigstore.dev/include: "true"
```

✅ **Phase 3 complete** - Image signed, manifests updated.

---

## Phase 4: Run Acceptance Tests

### Test 1: CVE Image Rejection (CI Level)

```bash
# 1. Modify Dockerfile to use vulnerable Python
cd temp/src/api
echo 'FROM python:3.8-slim' > Dockerfile.vulnerable

# 2. Push (intentionally breaking)
git add temp/src/api/Dockerfile
git commit -m "test: intentional CVE for verification"
git push

# 3. Expected: GitHub Actions ❌ RED (Trivy fail)

# 4. Fix it back
echo 'FROM python:3.13-slim' > temp/src/api/Dockerfile
git add temp/src/api/Dockerfile
git commit -m "fix: revert to clean image"
git push
```

**Expected**: CI workflow FAILS on Trivy scan.

### Test 2: Unsigned Image Rejection (Admission Webhook)

```bash
# Deploy unsigned nginx (should be rejected)
kubectl apply -f temp/policy-tests/unsigned-image-deployment.yaml

# Expected: ❌ Error: admission webhook "policy.sigstore.dev" denied the request

# Verify it was NOT created
kubectl -n demo get deployment unsigned-nginx
# Should NOT exist
```

**Expected**: Admission webhook REJECTS unsigned image.

### Test 3: Signed Image Deployment (Success Path)

```bash
# At this point, API image should be signed (from Phase 3)
# Verify rollout is deploying

kubectl -n demo get rollout api
# Should show: DESIRED=4, CURRENT=4, UP-TO-DATE=4, AVAILABLE=4

kubectl -n demo get pods
# Should see 4 running "api-*" pods (created recently)
```

**Expected**: Signed image PASSES admission webhook, pods running.

### Test 4a: Secret Rotation < 60s (Lab 2.1)

```bash
# Terminal 1: Watch secret value
watch kubectl -n demo get secret api-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d; echo

# Terminal 2: Update AWS secret
aws secretsmanager update-secret \
  --secret-id labw10/api/db \
  --secret-string '{"password":"updated-'$(date +%s)'"}' \
  --region ap-southeast-1

# Terminal 1: Watch for change within ~30-60 seconds
```

**Expected**: Secret updated in < 60s, NO pod restart.

### Test 4b: Pod Stability (Lab 2.1)

```bash
# Check pod AGE
kubectl -n demo get pods -l app=api

# Make multiple AWS secret updates (repeat Test 4a)
# Each time, AGE should NOT reset

# Expected: Pod AGE stays ~5min, ~10min, ~15min (never resets to 0s)
```

**Expected**: Pods NOT restarting on secret rotation.

### Test 4c: Repo Clean (Lab 2.1)

```bash
# Search for hardcoded secrets
grep -ri "password" . --include="*.yaml" --exclude-dir=.git
grep -ri "access-key" . --include="*.yaml" --exclude-dir=.git

# Expected: NO actual secret values, only mappings like:
# - "DB_PASSWORD_FILE: /var/run/secrets/db/password"
# - "key: labw10/api/db"
```

**Expected**: No hardcoded credentials in repo.

✅ **All 4 tests complete** - Labs passed!

---

## Phase 5: Sign-Off

### Checklist

- [ ] **Phase 1**: Cosign key generated, GitHub Secrets added
- [ ] **Phase 2**: ESO deployed, AWS secret syncing
- [ ] **Phase 3**: Image signed, manifests updated by CI
- [ ] **Test 1**: CVE image → CI RED ✓
- [ ] **Test 2**: Unsigned image → Admission REJECT ✓
- [ ] **Test 3**: Signed image → Deployment SUCCESS ✓
- [ ] **Test 4a**: Secret rotation < 60s ✓
- [ ] **Test 4b**: Pod AGE stable ✓
- [ ] **Test 4c**: Repo clean (no secrets) ✓

### Documentation

```bash
# Verify key documents exist
ls -la temp/SETUP-GUIDE.md
ls -la temp/ESO-SETUP.md
ls -la temp/COSIGN-PUBLIC-KEY-SETUP.md
ls -la temp/ACCEPTANCE-TESTS.md
ls -la temp/LAB-2.2-TRIVY-COSIGN.md
ls -la temp/.github/workflows/build-push.yml
```

✅ **All labs complete!**

---

## 🆘 If Stuck

| Component | Command |
|---|---|
| **CI Workflow** | `https://github.com/<repo>/actions` |
| **Policy Controller** | `kubectl -n cosign-system get pods` |
| **ESO Status** | `kubectl -n demo get externalsecret api-db-credentials` |
| **Secret Value** | `kubectl -n demo get secret api-db-credentials -o jsonpath='{.data.password}' \| base64 -d` |
| **Admission Logs** | `kubectl -n cosign-system logs -l app=policy-webhook -f` |
| **AWS Secret** | `aws secretsmanager get-secret-value --secret-id labw10/api/db` |

---

## 📞 Support

Refer to:
- `SETUP-GUIDE.md` - General setup
- `ESO-SETUP.md` - Lab 2.1 detailed steps
- `ACCEPTANCE-TESTS.md` - Complete test scenarios
- `LAB-2.2-TRIVY-COSIGN.md` - Original lab instructions

