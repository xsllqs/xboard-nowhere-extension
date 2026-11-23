#!/usr/bin/env bash
# Repository bootstrap: all application artifacts come from this repository.
set -euo pipefail
umask 077
VERSION=0.15.1
SHA256=dc7f0c457ee22e6c8786ab505e37c97d595bac6a98a09ef637c5c623761545ee
NODE_VERSION=0a29338e-go1.26.11
NODE_SHA256=802daf4560ccd67937ea15b3a2af038a8e29a40e41ccf78b02457b8bf4af0efe
REPOSITORY=https://raw.githubusercontent.com/xsllqs/xboard-nowhere-extension
usage() {
  cat <<'EOF'
Usage:
  bash install.sh machine --panel https://panel.example.com --token MACHINE_TOKEN --machine-id 123
  bash install.sh machine --panel https://panel.example.com --secret-file /root/machine-token --machine-id 123 --check
  bash install.sh machine                 # Reinstall/upgrade using saved extension credentials
  bash install.sh node [extension-only options]
machine installs Xboard-Node, xbctl and the Nowhere extension from this repository.
Linux amd64 + systemd required for machine/node. OS dependencies use apt/dnf/yum.
EOF
}
action=${1:-help}
case "$action" in
  help|-h|--help) usage;exit 0 ;;
  machine|node) shift ;;
  *) usage >&2;exit 2 ;;
esac
(( EUID == 0 )) || { echo 'Run as root' >&2;exit 1; }
for tool in curl sha256sum tar mktemp;do command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2;exit 1; };done
panel='';token='';machine='';secret='';check_only=0
if [[ "$action" == machine ]];then
  [[ $(uname -m) == x86_64 ]] || { echo 'This release supports Linux amd64 only' >&2;exit 1; }
  [[ $(uname -s) == Linux ]] || { echo 'Linux required' >&2;exit 1; }
  command -v systemctl >/dev/null || { echo 'systemd required' >&2;exit 1; }
  while (($#));do
    case "$1" in
      --panel) panel=${2:?panel required};shift 2 ;;
      --token) token=${2:?machine token required};shift 2 ;;
      --machine-id) machine=${2:?machine ID required};shift 2 ;;
      --secret-file) secret=${2:?secret file required};shift 2 ;;
      --check) check_only=1;shift ;;
      *) echo "Unknown machine option: $1" >&2;exit 2 ;;
    esac
  done
  saved=/etc/xboard-node/extensions/nowhere/agent.env
  if [[ -f "$saved" ]];then
    [[ -n "$panel" ]] || panel=$(sed -n 's/^PANEL_URL=//p' "$saved")
    [[ -n "$machine" ]] || machine=$(sed -n 's/^MACHINE_ID=//p' "$saved")
  fi
  [[ -n "$secret" ]] || secret=/etc/xboard-node/extensions/nowhere/control.secret
  if [[ -z "$token" && -f "$secret" && ! -L "$secret" ]];then token=$(tr -d '\r\n' < "$secret");fi
  [[ "$panel" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?/?$ ]] || { echo 'A plain HTTPS panel origin is required' >&2;exit 2; }
  [[ "$machine" =~ ^[1-9][0-9]*$ ]] || { echo 'Positive machine ID required' >&2;exit 2; }
  [[ "$token" =~ ^[a-zA-Z0-9_-]{32,256}$ ]] || { echo 'Valid per-machine token required' >&2;exit 2; }
fi
if ! command -v python3 >/dev/null;then
  [[ "$check_only" == 0 ]] || { echo 'python3 required for preflight' >&2;exit 1; }
  if command -v apt-get >/dev/null;then apt-get update -qq;apt-get install -y python3;
  elif command -v dnf >/dev/null;then dnf install -y python3;
  elif command -v yum >/dev/null;then yum install -y python3;
  else echo 'Install python3 first' >&2;exit 1;fi
fi
stage=$(mktemp -d /tmp/xboard-nowhere-download.XXXXXXXX)
trap 'rm -rf -- "$stage"' EXIT
fetch() {
  local path=$1 target=$2 checksum=$3
  curl --fail --location --show-error --retry 3 --connect-timeout 15 --max-time 300 \
    "$REPOSITORY/refs/tags/v$VERSION/$path" -o "$target"
  printf '%s  %s\n' "$checksum" "$target" | sha256sum --check -
}
fetch "packages/node-nowhere/$VERSION/xboard-node-nowhere-extension-$VERSION.tar.gz" "$stage/extension.tar.gz" "$SHA256"
tar -xzf "$stage/extension.tar.gz" -C "$stage"
extension="$stage/xboard-node-nowhere-extension-$VERSION"
if [[ "$action" != machine ]];then
  bash "$extension/install.sh" "$action" "$@"
  exit
fi
fetch "packages/xboard-node/$NODE_VERSION/xboard-node-$NODE_VERSION-linux-amd64.tar.gz" "$stage/xboard-node.tar.gz" "$NODE_SHA256"
tar -xzf "$stage/xboard-node.tar.gz" -C "$stage"
node="$stage/xboard-node-$NODE_VERSION"
"$node/xboard-node" -v
"$node/xbctl" version
printf '%s\n' "$token" > "$stage/machine.secret"
chmod 600 "$stage/machine.secret"
# Authenticate both the server identity and extension protocol before changing services.
python3 - "$panel" "$machine" "$stage/machine.secret" <<'PY'
import json,sys,urllib.request
from pathlib import Path
payload={'machine_id':int(sys.argv[2]),'protocol_version':3,'device_support':True,'reports':[]}
request=urllib.request.Request(sys.argv[1].rstrip('/')+'/api/v1/nowhere/control',
    data=json.dumps(payload).encode(),headers={'Authorization':'Bearer '+Path(sys.argv[3]).read_text().strip(),
    'Content-Type':'application/json','User-Agent':'Xboard-Node-Nowhere-Bootstrap/0.15'})
try:
    with urllib.request.urlopen(request,timeout=15) as response: result=json.load(response)
    assert result.get('protocol_version')==3 and isinstance(result.get('nodes'),list)
    assert result.get('sync_settings',{}).get('device_mode')=='native_snapshot'
except Exception as error:
    raise SystemExit('Panel authentication/compatibility failed: '+type(error).__name__)
print('Machine authentication and Nowhere protocol preflight passed')
PY
if [[ "$check_only" == 1 ]];then echo 'Preflight passed; no services or configuration changed';exit;fi
bash "$node/install.sh" --mode machine --panel "$panel" --token "$token" --machine-id "$machine" \
  --binary "$node/xboard-node" --xbctl-binary "$node/xbctl" --version "$NODE_VERSION" --yes
bash "$extension/install.sh" node --panel "$panel" --machine-id "$machine" --secret-file "$stage/machine.secret"
echo 'Xboard-Node and Nowhere extension installed from xsllqs/xboard-nowhere-extension'
