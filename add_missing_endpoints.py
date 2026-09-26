import json

with open("backend/EasyClaim.postman_collection.json", "r") as f:
    data = json.load(f)

for category in data["item"]:
    if category["name"] == "3. Claims Standard 6-Stage Flow":
        category["item"].insert(0, {
            "name": "System: Check Claims Service Status",
            "request": {
                "method": "GET",
                "url": {
                    "raw": "{{baseUrl}}/api/v1/claims/status",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "claims", "status"]
                }
            }
        })
        category["item"].insert(9, { # Insert near decision POST
            "name": "Stage 5: Get Decision",
            "request": {
                "method": "GET",
                "url": {
                    "raw": "{{baseUrl}}/api/v1/claims/{{claimId}}/decision",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "claims", "{{claimId}}", "decision"]
                }
            }
        })

# Check if OCR exists, if not add it
ocr_exists = any(c.get("name") == "5. OCR Service" for c in data["item"])
if not ocr_exists:
    data["item"].append({
        "name": "5. OCR Service",
        "item": [
            {
                "name": "Process Document OCR",
                "request": {
                    "method": "POST",
                    "header": [
                        {
                            "key": "Content-Type",
                            "value": "application/json"
                        }
                    ],
                    "body": {
                        "mode": "raw",
                        "raw": "{\n  \"documentUrl\": \"https://example.com/invoice.pdf\"\n}"
                    },
                    "url": {
                        "raw": "{{baseUrl}}/api/v1/ocr/process",
                        "host": ["{{baseUrl}}"],
                        "path": ["api", "v1", "ocr", "process"]
                    }
                }
            }
        ]
    })

with open("backend/EasyClaim.postman_collection.json", "w") as f:
    json.dump(data, f, indent=4)
