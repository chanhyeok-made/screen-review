#!/usr/bin/env bash
# ScreenReview goes into any app: UIKit and SwiftUI only, nothing of any service's.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
check() { # dir, allowed-imports regex
  local dir=$1 allowed=$2
  while IFS= read -r line; do
    file=${line%%:*}; mod=$(sed -E 's/.*import[[:space:]]+([A-Za-z_]+).*/\1/' <<<"${line#*:}")
    if ! [[ $mod =~ ^($allowed)$ ]]; then echo "layer: $file imports $mod"; fail=1; fi
  done < <(grep -rEn '^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]' "$dir" --include='*.swift' | cut -d: -f1,3- || true)
}
check Sources/ScreenReview 'Foundation|SwiftUI|UIKit'
check Tests/ScreenReviewTests 'Foundation|SwiftUI|UIKit|XCTest|ScreenReview'
exit $fail
