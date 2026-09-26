import json

with open("backend/EasyClaim.postman_collection.json", "r") as f:
    data = json.load(f)

# Find Claims Wizard
for category in data["item"]:
    if category["name"] == "3. Claims Wizard (6-Stage Flow)":
        for item in category["item"]:
            if item["name"] == "Step 1: Initiate (Category)":
                # Add test script to capture claimId
                item["event"] = [
                    {
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
                ]
            else:
                # Replace 'claim_disc_101' with '{{claimId}}' in raw url and path
                url = item["request"]["url"]
                if "claim_disc_101" in url["raw"]:
                    url["raw"] = url["raw"].replace("claim_disc_101", "{{claimId}}")
                
                new_path = []
                for p in url.get("path", []):
                    if p == "claim_disc_101":
                        new_path.append("{{claimId}}")
                    else:
                        new_path.append(p)
                url["path"] = new_path

# Add claimId variable to collection variables if not present
vars = data.get("variable", [])
has_claimId = any(v.get("key") == "claimId" for v in vars)
if not has_claimId:
    vars.append({
        "key": "claimId",
        "value": "",
        "type": "string"
    })
    data["variable"] = vars

with open("backend/EasyClaim.postman_collection.json", "w") as f:
    json.dump(data, f, indent=4)
