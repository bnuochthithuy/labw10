# ESO Secret Rotation Lab

This folder is safe to commit. It contains only the mapping from AWS Secrets Manager
to a Kubernetes Secret, not the secret value or AWS credentials.

Create the AWS credential Secret manually:

```bash
kubectl -n demo create secret generic aws-secret-manager-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY"
```

Create or update this AWS Secrets Manager secret:

```json
{
  "password": "change-me-outside-git"
}
```

Expected source key:

```text
labw10/api/db
```

Validate rotation:

```bash
kubectl -n demo get secret api-db-credentials -o jsonpath='{.data.password}' | base64 -d
kubectl -n demo get pod -l app=api
```

`refreshInterval: 30s` keeps the lab under 60 seconds without polling AWS too
aggressively. The API pod mounts the Secret as a volume, so the file content can
change without a pod restart. Do not consume the password through an env var if
you want no-restart rotation.
