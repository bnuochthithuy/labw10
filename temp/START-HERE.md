# 🎓 Lab 2.1 & 2.2: Execution Summary

## Status: ✅ ALL SETUP DOCUMENTS READY

Tất cả các tài liệu hướng dẫn đã được chuẩn bị. Bây giờ bạn cần **thực hiện từng bước**.

---

## 📖 Hướng Dẫn Chính

**👉 BẮT ĐẦU TẠI ĐÂY**: [QUICK-START.md](./QUICK-START.md)

Nó bao gồm 5 Phase rõ ràng:
1. **Phase 1**: Generate Cosign keypair + GitHub Secrets
2. **Phase 2**: Setup ESO (AWS Secret Manager)
3. **Phase 3**: Push code → CI auto-builds & signs image
4. **Phase 4**: Run 4 test cases
5. **Phase 5**: Sign-off & acceptance

---

## 📚 Tài Liệu Hỗ Trợ

Tùy theo bạn cần chi tiết về phần nào:

| Phần | Tài Liệu | Mục đích |
|---|---|---|
| **Setup tổng quát** | [SETUP-GUIDE.md](./SETUP-GUIDE.md) | Tổng quan + checklist |
| **Lab 2.1 (ESO)** | [ESO-SETUP.md](./ESO-SETUP.md) | Chi tiết ESO rotation |
| **Lab 2.2 (Cosign)** | [COSIGN-PUBLIC-KEY-SETUP.md](./COSIGN-PUBLIC-KEY-SETUP.md) | Chi tiết public key |
| **Tests** | [ACCEPTANCE-TESTS.md](./ACCEPTANCE-TESTS.md) | 4 test case + troubleshooting |
| **Yêu cầu gốc** | [LAB-2.2-TRIVY-COSIGN.md](./LAB-2.2-TRIVY-COSIGN.md) | Bài lab gốc (tiếng Việt) |

---

## ⚡ Bước Đầu Tiên (HÔM NAY)

### Immediate Action: Tạo Cosign Keypair

```bash
# 1. Go to labw10 directory
cd d:\gitOps\labw10

# 2. Generate keypair
C:/Users/User/tools/cosign.exe generate-key-pair

# Follow prompts:
# Enter password for private key: [your-secure-password]
# Enter password for private key again: [repeat]

# Output:
# cosign.key (PRIVATE - keep safe!)
# cosign.pub (PUBLIC - commit to repo)
```

**⏭️ Sau đó:**
1. Copy password vừa nhập → **GitHub Secrets**
2. Commit cosign.pub → **git push**
3. Follow **QUICK-START.md Phase 1** chi tiết

---

## 🔑 GitHub Secrets (MUST DO)

```
Repo Settings → Secrets and variables → Actions
```

Tạo 2 secrets này:

| Secret Name | Value | Source |
|---|---|---|
| `COSIGN_PRIVATE_KEY` | Nội dung file `cosign.key` | File tạo từ cosign |
| `COSIGN_PASSWORD` | Password bạn nhập | Từ step trên |

**⚠️ Quan trọng**: Không hardcode password, dùng GitHub Secrets!

---

## 🧪 Preview: 3 Main Tests

### Test 1: Trivy Fail on CVE ❌
```bash
# Intentionally use old Python version
# Push → CI fails
# Expected: GitHub Actions RED
```

### Test 2: Unsigned Image Rejected ❌
```bash
# Deploy unsigned nginx
# Expected: admission webhook deny
```

### Test 3: Signed Image Pass ✅
```bash
# Clean image → deployed successfully
# Expected: pods running, no restart
```

---

## 📊 Workflow Overview

```
Your Code (Push)
        ↓
GitHub Actions CI
        ├─ Build image
        ├─ Trivy scan (fail if CVE)
        ├─ Push to GHCR
        ├─ Sign with Cosign
        └─ Update manifests
        ↓
ArgoCD syncs
        ├─ policy-controller (admission webhook)
        ├─ policies (ClusterImagePolicy)
        └─ app-api (Rollout)
        ↓
K8s Admission Webhook
        ├─ Verify signature
        ├─ Check policy label
        └─ Allow/Deny deployment
        ↓
ESO (continuous)
        ├─ Watch AWS secret
        ├─ Sync to K8s
        └─ Every 30s (no pod restart)
```

---

## ✅ Verification Checklist

**Before starting Phase 1:**
- [ ] cosign command available
- [ ] trivy command available
- [ ] kubectl connected to cluster
- [ ] git repo clean
- [ ] AWS credentials configured

**After Phase 1:**
- [ ] cosign.pub in `temp/signing/`
- [ ] GitHub Secrets created
- [ ] Files committed & pushed

**After Phase 2:**
- [ ] AWS secret created
- [ ] K8s secret created
- [ ] ESO pods running

**After Phase 3:**
- [ ] GitHub Actions SUCCESS (green)
- [ ] Image signed (manifest updated)
- [ ] namespace labeled

**After Phase 4:**
- [ ] All 4 tests PASSED

---

## 🚨 If You Get Stuck

### "cosign command not found"
```bash
C:/Users/User/tools/cosign.exe generate-key-pair
# Use full path instead
```

### "passwords do not match"
```bash
# Re-run, type SAME password twice
C:/Users/User/tools/cosign.exe generate-key-pair
```

### "GitHub Actions fails"
```bash
# Check workflow logs at:
# https://github.com/<repo>/actions
# Look for error messages
```

### "Admission webhook rejects ALL images"
```bash
# Check namespace label:
kubectl get ns demo --show-labels
# If missing policy.sigstore.dev/include=true, label it:
# kubectl label ns demo policy.sigstore.dev/include=true
```

### "Secret not syncing from AWS"
```bash
# Check ESO:
kubectl -n external-secrets get pods
kubectl -n demo describe externalsecret api-db-credentials
```

---

## 📞 Full Support

For detailed help, refer to:
- **Phase-by-phase**: [QUICK-START.md](./QUICK-START.md)
- **Troubleshooting**: [ACCEPTANCE-TESTS.md](./ACCEPTANCE-TESTS.md)
- **Deep dive**: See specific `.md` files

---

## 🎯 Next Action

1. ➡️ Open [QUICK-START.md](./QUICK-START.md)
2. ➡️ Follow **Phase 1** step-by-step
3. ➡️ Report back when you hit any issues
4. ➡️ We'll debug together

**Good luck! 🚀**

