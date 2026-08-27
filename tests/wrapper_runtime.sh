#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="${SOPACKER_TEST_ROOT:?set SOPACKER_TEST_ROOT outside /tmp}"
CASE_DIR="$(mktemp -d "${TEST_ROOT%/}/wrapper-runtime.XXXXXX")"
trap 'rm -rf "${CASE_DIR}"' EXIT

PAYLOAD_DIR="${CASE_DIR}/payload"
RUNTIME_DIR="${CASE_DIR}/runtime"
WRAPPER="${CASE_DIR}/packed-program"
mkdir -p "${PAYLOAD_DIR}"

cat >"${PAYLOAD_DIR}/test-loader" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test "$1" = "--library-path"
shift 2
exec "$@"
EOF

cat >"${PAYLOAD_DIR}/test-program" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "hold" ]; then
    : >"$2"
    sleep 2
    exit 0
fi
exit 37
EOF
chmod +x "${PAYLOAD_DIR}/test-loader" "${PAYLOAD_DIR}/test-program"

awk 'copy { print } /^__UNPACK_FOLLOWS__$/ { copy = 1 }' \
    "${ROOT_DIR}/packer" >"${WRAPPER}"
sed -i "2a\\bundle_id=wrapper-runtime-test" "${WRAPPER}"
sed -i "2a\\interpname=test-loader" "${WRAPPER}"
sed -i "2a\\execname=test-program" "${WRAPPER}"
sed -i "2a\\tempdir=${RUNTIME_DIR}" "${WRAPPER}"
tar -C "${PAYLOAD_DIR}" -cf - test-loader test-program >>"${WRAPPER}"
chmod +x "${WRAPPER}"

set +e
"${WRAPPER}"
status=$?
set -e

if [ "${status}" -ne 37 ]; then
    echo "expected packed program exit status 37, got ${status}" >&2
    exit 1
fi

STARTED_FILE="${CASE_DIR}/holder-started"
"${WRAPPER}" hold "${STARTED_FILE}" &
holder_pid=$!
for _ in $(seq 1 100); do
    [ -e "${STARTED_FILE}" ] && break
    sleep 0.01
done
if [ ! -e "${STARTED_FILE}" ]; then
    wait "${holder_pid}"
    echo "holder program did not start" >&2
    exit 1
fi

set +e
timeout 1 "${WRAPPER}"
concurrent_status=$?
set -e
wait "${holder_pid}"

if [ "${concurrent_status}" -ne 37 ]; then
    echo "expected concurrent wrapper status 37, got ${concurrent_status}" >&2
    exit 1
fi

if grep -q 'ld-linux-x86-64\.so\.2' "${ROOT_DIR}/packer"; then
    echo "packer must derive the ELF interpreter instead of assuming x86_64" >&2
    exit 1
fi

if ! grep -Fq 'Usage: ./packer [executable_file ...]' "${ROOT_DIR}/README.md"; then
    echo "README must document multi-executable packaging" >&2
    exit 1
fi
