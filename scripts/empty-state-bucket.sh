#!/usr/bin/env bash
# Esvazia (todas as versoes e marcadores) e apaga o bucket de state. IRREVERSIVEL.
# Padrao: so lista o que apagaria. Use --yes para apagar de verdade.
set -euo pipefail
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="aws-lab-tfstate-${ACCOUNT_ID}"
YES=0; [[ "${1:-}" == "--yes" ]] && YES=1

python3 - "$BUCKET" "$YES" <<'PY'
import json, subprocess, sys
bucket, yes = sys.argv[1], sys.argv[2] == "1"
def aws(*a): return json.loads(subprocess.run(["aws", *a, "--output", "json"], check=True, capture_output=True, text=True).stdout or "{}")
objs, token = [], {}
while True:
    args = ["s3api", "list-object-versions", "--bucket", bucket, "--max-items", "1000"]
    if token.get("NextToken"): args += ["--starting-token", token["NextToken"]]
    r = aws(*args)
    objs += [{"Key": o["Key"], "VersionId": o["VersionId"]} for o in (r.get("Versions") or []) + (r.get("DeleteMarkers") or [])]
    token = r
    if not r.get("NextToken"): break
print(f"{len(objs)} versoes/marcadores em s3://{bucket}")
if not yes:
    for o in objs[:20]: print("  ", o["Key"])
    print("Dry-run. Rode com --yes para apagar tudo e remover o bucket."); sys.exit(0)
for i in range(0, len(objs), 1000):
    batch = {"Objects": objs[i:i+1000], "Quiet": True}
    subprocess.run(["aws", "s3api", "delete-objects", "--bucket", bucket, "--delete", json.dumps(batch)], check=True)
subprocess.run(["aws", "s3api", "delete-bucket", "--bucket", bucket], check=True)
print("Bucket removido.")
PY
