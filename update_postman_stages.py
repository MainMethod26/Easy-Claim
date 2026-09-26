import json

with open("backend/EasyClaim.postman_collection.json", "r") as f:
    data = json.load(f)

for category in data["item"]:
    if category["name"] == "3. Claims Wizard (6-Stage Flow)":
        category["name"] = "3. Claims Standard 6-Stage Flow"
        
        # Keep Step 1 and Evidence, but let's just rewrite this category's items entirely.
        
        # Capture claimId script for Step 1
        capture_script = {
            "listen": "test",
            "script": {
                "exec": [
                    "var jsonData = pm.response.json();",
                    "if (jsonData.claimId) {",
                    "    pm.collectionVariables.set(\"claimId\", jsonData.claimId);",
                    "}"
                ],
                "type": "text/javascript"
            }
        }
        
        category["item"] = [
            {
                "name": "Intake: Initiate",
                "event": [capture_script],
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/initiate", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "initiate"] }
                }
            },
            {
                "name": "Intake: Evidence Upload (OCR)",
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/evidence-ocr", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "evidence-ocr"] }
                }
            },
            {
                "name": "Stage 1: Submitted",
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/submit", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "submit"] }
                }
            },
            {
                "name": "Stage 2: Verified",
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/verify", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "verify"] }
                }
            },
            {
                "name": "Stage 3: Screening",
                "request": {
                    "method": "PATCH",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/screening", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "screening"] }
                }
            },
            {
                "name": "Side State: Info Needed",
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/info-needed", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "info-needed"] }
                }
            },
            {
                "name": "Stage 4: Review",
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/review", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "review"] }
                }
            },
            {
                "name": "Stage 5: Decision",
                "request": {
                    "method": "POST",
                    "header": [{"key": "Content-Type", "value": "application/json"}],
                    "body": {"mode": "raw", "raw": "{\"decision\": \"approved\"}"},
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/decision", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "decision"] }
                }
            },
            {
                "name": "Side State: Rejected",
                "request": {
                    "method": "POST",
                    "header": [{"key": "Content-Type", "value": "application/json"}],
                    "body": {"mode": "raw", "raw": "{\"reason\": \"Wear and tear\"}"},
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/reject", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "reject"] }
                }
            },
            {
                "name": "Side State: Appeal",
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/appeal", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "appeal"] }
                }
            },
            {
                "name": "Stage 6: Paid",
                "request": {
                    "method": "POST",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/pay", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "pay"] }
                }
            },
            {
                "name": "Status Timeline",
                "request": {
                    "method": "GET",
                    "url": { "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/timeline", "host": ["{{baseUrl}}"], "path": ["api", "v1", "claims", "{{claimId}}", "timeline"] }
                }
            }
        ]
        break

with open("backend/EasyClaim.postman_collection.json", "w") as f:
    json.dump(data, f, indent=4)
