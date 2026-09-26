import json

with open("backend/EasyClaim.postman_collection.json", "r") as f:
    data = json.load(f)

for category in data["item"]:
    if category["name"] == "4. Identity & Audit Services":
        category["item"].insert(0, {
            "name": "Login with SA ID",
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
                    "raw": "{\n  \"idNumber\": \"8505125021087\"\n}"
                },
                "url": {
                    "raw": "{{baseUrl}}/api/v1/profile/login",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "profile", "login"]
                }
            }
        })
        break

with open("backend/EasyClaim.postman_collection.json", "w") as f:
    json.dump(data, f, indent=4)
