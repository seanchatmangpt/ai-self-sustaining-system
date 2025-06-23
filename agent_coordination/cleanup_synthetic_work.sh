#\!/bin/bash
# Remove synthetic benchmark work items
echo "Removing synthetic benchmark work items..."
jq 'map(select(.description | contains("benchmark_test") | not))' work_claims.json > work_claims_clean.json
mv work_claims_clean.json work_claims.json
echo "Cleaned work items. Remaining: $(jq 'length' work_claims.json)"
EOF < /dev/null