# Lab 2.1 & 2.2: Verification & Acceptance Tests

## 📋 Pre-requisites Checklist

### Setup Environment
- [ ] `cosign` executable available (`/usr/local/bin/cosign` or `C:/Users/.../tools/cosign.exe`)
- [ ] `trivy` CLI installed
- [ ] `kubectl` connected to K8s cluster (minikube/AKS/EKS)
- [ ] `git` repo cloned and `main` branch clean
- [ ] AWS credentials configured (for Lab 2.1 ESO)

### Lab 2.2: Cosign Setup
- [ ] `cosign generate-key-pair` completed (cosign.key + cosign.pub)
- [ ] GitHub Secrets added:
  - `COSIGN_PRIVATE_KEY` = contents of cosign.key
  - `COSIGN_PASSWORD` = password from key generation
- [ ] `temp/signing/cosign.pub` committed
- [ ] `temp/policies/cluster-image-policy.yaml` contains public key
- [ ] `temp/app-common/demo-namespace.yaml` has label `policy.sigstore.dev/include: "true"`
- [ ] ArgoCD apps deployed:
  - `policy-controller.yaml` → Sigstore Policy Controller pod running
  - `policies.yaml` → ClusterImagePolicy synced

### Lab 2.1: ESO Setup  
- [ ] `external-secrets` pod running (`kubectl -n external-secrets get pods`)
- [ ] AWS Secrets Manager secret created: `labw10/api/db`
- [ ] K8s Secret created: `aws-secret-manager-credentials` in `demo` namespace
- [ ] `temp/eso/secret-store.yaml` applied
- [ ] `temp/eso/external-secret.yaml` applied
- [ ] ExternalSecret status = "SecretSynced"

---

## 🧪 Test 1: Push Image with CVE HIGH/CRITICAL

### Setup: Create vulnerable image

```bash
# Option A: Modify Dockerfile to use old base image
cd temp/src/api
cat Dockerfile
# FROM python:3.8-slim  ← Use old Python version (has known CVE)

# Commit and push
git add temp/src/api/Dockerfile
git commit -m "test: use python:3.8 (has CVE)"
git push
```

### Expected Result

```
GitHub Actions Workflow: ❌ FAILED (RED)
```

Check workflow logs:
```bash
# In GitHub Actions UI, look for:
# "trivy image --exit-code 1 --severity HIGH,CRITICAL $IMAGE"
# Output: "3 HIGH vulnerabilities found"
```

### Accept Criteria
- ✅ CI workflow status: RED
- ✅ Trivy scan failed on HIGH/CRITICAL CVE
- ✅ Image NOT pushed to GHCR
- ✅ Cosign sign step NOT executed

### Remediation (If needed)
```bash
# Update Dockerfile to use non-vulnerable Python
# FROM python:3.13-slim  ← Use latest Python

git add temp/src/api/Dockerfile
git commit -m "fix: update to python:3.13 (CVE-free)"
git push
```

---

## 🧪 Test 2: Deploy Unsigned Image → Admission Webhook REJECT

### Setup: Deploy nginx (not signed)

```bash
# Verify namespace has policy label
kubectl get ns demo --show-labels
# Output: policy.sigstore.dev/include=true ✓

# Try to deploy unsigned image
kubectl apply -f temp/policy-tests/unsigned-image-deployment.yaml
```

### Expected Result

```
❌ Error: admission webhook "policy.sigstore.dev" denied the request
Error from server: error when creating "unsigned-image-deployment.yaml": admission webhook "policy.sigstore.dev" denied the request: image ghcr.io/... is not signed
```

### Accept Criteria
- ✅ Admission webhook rejects unsigned image
- ✅ Deployment NOT created
- ✅ Error message contains "policy.sigstore.dev denied the request"

### Debugging (If webhook not triggered)

```bash
# 1. Check policy-controller is running
kubectl -n cosign-system get pods -l app=policy-webhook

# 2. Check ClusterImagePolicy exists
kubectl get clusterimagepolicies
kubectl describe clusterimagepolicy require-signed-images

# 3. Check namespace label
kubectl get ns demo -o yaml | grep policy.sigstore.dev

# 4. Check webhook validation rules
kubectl get validatingwebhookconfigurations | grep policy
```

---

## 🧪 Test 3: Deploy Signed Image → PASS

### Setup: Build & sign image (clean)

```bash
# 1. Make sure Dockerfile is clean (no CVE)
cd temp/src/api
# FROM python:3.13-slim  ← Clean version

# 2. Push to trigger CI
git add temp/src/api/
git commit -m "feat: add api v1"
git push

# 3. Wait for GitHub Actions to complete
# Monitor: https://github.com/<repo>/actions
```

### Expected Result (CI Success)

```
GitHub Actions Workflow: ✅ SUCCESS (GREEN)

Steps executed:
1. Build image ✓
2. Trivy scan (0 HIGH/CRITICAL) ✓
3. Push image to GHCR ✓
4. Sign image with Cosign ✓
5. Update manifests (signing/cosign.pub) ✓
6. Commit & push changes ✓
```

### Expected Result (Deployment Success)

```bash
# Verify image rolled out
kubectl -n demo get rollout api
# NAME   DESIRED   CURRENT   UP-TO-DATE   AVAILABLE
# api    4         4         4            4

# Check pods (AGE should be recent, no restart)
kubectl -n demo get pods
# Pod names starting with "api-..." should have created recently

# Verify secret mounted (Lab 2.1)
kubectl -n demo get pods -l app=api \
  -o jsonpath='{.items[0].spec.volumes[?(@.name=="db-credentials")].secret.secretName}'
# Output: api-db-credentials

# Verify ExternalSecret synced
kubectl -n demo get externalsecret api-db-credentials
# STATUS   AGE
# synced   2m3s

# Read secret value (should match AWS)
kubectl -n demo get secret api-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d
# Output: (password value from AWS)
```

### Accept Criteria
- ✅ CI workflow: GREEN (all steps passed)
- ✅ Image pushed to GHCR with SHA tag
- ✅ Image signed with Cosign
- ✅ Rollout pods running (4 replicas)
- ✅ Pods NOT restarting (AGE stable)
- ✅ ExternalSecret synced (secret rotated from AWS)
- ✅ No admission webhook rejection

---

## 🧪 Lab 2.1 Specific: Secret Rotation Test

### Test 4a: Change AWS secret → K8s auto-updates (< 60s)

```bash
# Terminal 1: Watch K8s secret
watch kubectl -n demo get secret api-db-credentials \
  -o jsonpath='{.data.password}' | base64 -d; echo

# Terminal 2: Update AWS secret
INITIAL_VALUE="password-before-change"
NEW_VALUE="password-after-change-$(date +%s)"

aws secretsmanager update-secret \
  --secret-id labw10/api/db \
  --secret-string "{\"password\":\"$NEW_VALUE\"}" \
  --region ap-southeast-1

# Terminal 1: Should see value change within 30-60 seconds
```

### Expected Result
```
✅ K8s secret updated < 60 seconds (usually ~30s due to refreshInterval)
✅ Pod(s) AGE did NOT reset (no restart)
```

### Accept Criteria
- ✅ AWS secret changed
- ✅ K8s secret automatically updated < 60s
- ✅ Pod(s) not restarted (check AGE column stable)
- ✅ ExternalSecret.status = "synced"

### Test 4b: Repo should be clean

```bash
# Search for hardcoded secrets
grep -ri "password" . --include="*.yaml" --include="*.yml" --include="*.py" --exclude-dir=.git

# Expected: Only mapping references, no actual values
# Example OK: "DB_PASSWORD_FILE: /var/run/secrets/db/password"
# Example BAD: "password: initial-password-123"

grep -ri "secret" . --include="*.env" --include="*.txt"
# Expected: No .env files with credentials (should be in .gitignore)

cat .gitignore
# Should include: cosign.key, .env, email-secret.yaml, etc.
```

### Accept Criteria
- ✅ No hardcoded secret values in repo
- ✅ Only metadata/mappings visible
- ✅ Credentials stored in AWS Secrets Manager / K8s Secrets
- ✅ cosign.key in .gitignore

---

## 📊 Final Sign-Off Checklist

### Lab 2.2: Trivy + Cosign
- [ ] Test 1 PASSED: CVE image → CI RED
- [ ] Test 2 PASSED: Unsigned image → Admission REJECT
- [ ] Test 3 PASSED: Signed image → Deployment SUCCESS
- [ ] Workflow logs show all steps completed
- [ ] cosign.pub committed in repo
- [ ] cluster-image-policy.yaml has correct public key

### Lab 2.1: ESO Secret Rotation
- [ ] Test 4a PASSED: Secret rotated < 60s
- [ ] Test 4b PASSED: Pod AGE stable (no restart)
- [ ] Test 4c PASSED: Repo clean (no hardcoded secrets)
- [ ] ExternalSecret syncing continuously
- [ ] AWS secret readable from K8s pod

### Overall
- [ ] All 4 tests PASSED
- [ ] No CVEs outstanding
- [ ] No security violations
- [ ] All workflows green
- [ ] Repository clean & secure

---

## 🆘 Quick Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Test 1 fails (no CVE found) | Trivy DB outdated | `trivy image --download-db-only` |
| Test 2 passes (should reject) | Policy label missing | `kubectl label ns demo policy.sigstore.dev/include=true` |
| Test 3 fails (image not signed) | COSIGN_PRIVATE_KEY secret wrong | Verify GitHub Secret content |
| Test 4a timeout (secret no update) | ESO pod not running | `kubectl -n external-secrets get pods` |
| Test 4b finds hardcoded value | .gitignore missing | Add secret patterns to `.gitignore` |

---

## 📝 Notes

- All tests should be run in order
- Each test is independent (no dependencies)
- Tests can be repeated multiple times
- Expected behavior should match exactly
- Document any deviations in comments

