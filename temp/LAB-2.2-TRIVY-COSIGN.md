# Lab 2.2 - Trivy + Cosign

Muc tieu:

- Push image co CVE HIGH/CRITICAL thi GitHub Actions fail.
- Deploy image chua ky thi policy-controller reject.
- Deploy image da ky bang Cosign thi pass.

## 1. Image tag chuan

Workflow dung tag bat bien theo commit:

```bash
IMAGE=ghcr.io/bnuochthithuy/w10-api:${GITHUB_SHA}
```

Khong dung `latest`.

## 2. GitHub Secrets

Tao keypair local:

```bash
cosign generate-key-pair
```

Them vao GitHub repo secrets:

- `COSIGN_PRIVATE_KEY`: noi dung file `cosign.key`
- `COSIGN_PASSWORD`: password da nhap khi tao key

Sau do dan noi dung `cosign.pub` vao hai file nay, hoac de CI tu cap nhat sau lan sign dau tien:

```text
signing/cosign.pub
temp/policies/cluster-image-policy.yaml
```

Thay dong `REPLACE_WITH_COSIGN_PUBLIC_KEY`.

## 3. CI flow

File `.github/workflows/build-push.yml` dang chay theo thu tu:

1. Build image tu `temp/src/api`.
2. Scan bang Trivy:

```bash
trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMAGE"
```

3. Push image len GHCR.
4. Sign image bang Cosign.
5. Xuat public key tu private key va cap nhat `signing/cosign.pub`.
6. Dan public key vao `temp/policies/cluster-image-policy.yaml`.
7. Cap nhat `temp/app-api/rollout.yaml` sang image SHA da ky.
8. Gan label `policy.sigstore.dev/include=true` cho namespace `demo` sau khi sign thanh cong.

## 4. GitOps policy

Policy controller va policies duoc cai bang ArgoCD:

```bash
kubectl apply -f temp/argocd/apps/policy-controller.yaml
kubectl apply -f temp/argocd/apps/policies.yaml
```

Neu ban dung root app, hai file nay nam trong `temp/argocd/apps` nen root app se tu sync.

Namespace `demo` chi nen co label sau khi image da duoc CI scan va ky:

```yaml
policy.sigstore.dev/include: "true"
```

Neu test bang namespace `default`, chay them:

```bash
kubectl label ns default policy.sigstore.dev/include=true
```

## 5. Test nghiem thu

Test unsigned image bi reject:

```bash
kubectl apply -f temp/policy-tests/unsigned-image-deployment.yaml
```

Ket qua mong doi:

```text
admission webhook "policy.sigstore.dev" denied the request
```

Test signed image pass:

```bash
git push origin main
kubectl get rollout api -n demo
kubectl get pods -n demo
```

Checklist:

- [ ] Trivy block HIGH/CRITICAL
- [ ] Cosign keypair tao xong
- [ ] `COSIGN_PRIVATE_KEY` va `COSIGN_PASSWORD` da them vao GitHub Secrets
- [ ] `cosign.pub` da dan vao `temp/policies/cluster-image-policy.yaml`
- [ ] Image duoc sign trong CI
- [ ] Policy controller chay trong `cosign-system`
- [ ] ClusterImagePolicy da apply
- [ ] Namespace co label `policy.sigstore.dev/include=true`
- [ ] Unsigned image bi reject
- [ ] Signed image deploy OK
