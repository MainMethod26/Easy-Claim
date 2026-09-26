import json

with open("backend/EasyClaim.postman_collection.json", "r") as f:
    data = json.load(f)

# Find Identity & Audit Services item
for category in data["item"]:
    if category["name"] == "4. Identity & Audit Services":
        items = category["item"]
        
        # Add Update Profile
        items.insert(1, {
            "name": "Update Profile",
            "request": {
                "method": "PATCH",
                "header": [ { "key": "Content-Type", "value": "application/json" } ],
                "body": { "mode": "raw", "raw": "{\n  \"riskProfile\": \"Medium\"\n}" },
                "url": {
                    "raw": "{{baseUrl}}/api/v1/profile",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "profile"]
                }
            }
        })
        
        # Add Check Mandate
        # Assuming we insert it before Cancel Mandate
        cancel_idx = next(i for i, v in enumerate(items) if v["name"] == "Cancel Mandate")
        items.insert(cancel_idx, {
            "name": "Check Mandate",
            "request": {
                "method": "GET",
                "url": {
                    "raw": "{{baseUrl}}/api/v1/profile/mandates/tenant_123/check",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "profile", "mandates", "tenant_123", "check"]
                }
            }
        })
        
        # Add Audit Trail at the end
        items.append({
            "name": "Audit Trail",
            "request": {
                "method": "GET",
                "url": {
                    "raw": "{{baseUrl}}/api/v1/activities/audit-trail",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "activities", "audit-trail"]
                }
            }
        })
        break

with open("backend/EasyClaim.postman_collection.json", "w") as f:
    json.dump(data, f, indent=4)
