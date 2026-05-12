#!/bin/bash
# Load test script for POST /api/campaigns based on DEVELOPMENT_HANDOFF.md

# Env Vars from Section 5
PORT="${PORT:-3000}"
HOST="http://localhost:${PORT}"
TOKEN="TOKEN" # Placeholder for actual token

echo "Starting load test for POST /api/campaigns..."

# Simulate 10 parallel requests
for i in {1..10}; do
  # Request from Section 1: API PAYLOAD EXAMPLES
  # Upload Spec from Section 3: image (5MB limit, jpg/png/pdf) -> cloudinary: disasteraid/ngo_docs
  curl -s -X POST "${HOST}/api/campaigns" \
    -H "Authorization: Bearer ${TOKEN}" \
    -F "title=Food Drive 2024 Load Test $i" \
    -F "description=Urgent food aid for flood victims in Sindh - Load Test Data" \
    -F "category=FOOD" \
    -F "target_amount=500000" \
    -F "location=Sindh" \
    -F "end_date=2024-12-31" \
    -F "image=@photo.jpg" &
done

wait
echo "Load test completed."