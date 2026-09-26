import json

with open("backend/EasyClaim.postman_collection.json", "r") as f:
    data = json.load(f)

for category in data["item"]:
    if category["name"] == "2. Policy Service":
        category["item"].append({
            "name": "Submit Insurance Requirements",
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
                    "raw": json.dumps({
                        "governmentId": "passport_12345.pdf",
                        "proofOfAddress": "utility_bill_oct.pdf",
                        "taxIdentification": "tax_987654321",
                        "assetDetails": "VIN_XYZ123456789",
                        "proofOfOwnership": "vehicle_registration.pdf",
                        "riskDisclosure": {"medicalHistory": "None", "propertySecurity": "Alarm system"},
                        "truthfulDisclosureDeclaration": True,
                        "claimsHistory": "no_claims_last_3_years.pdf",
                        "paymentDetails": {"method": "EFT", "bank": "Standard Bank"},
                        "financialInterestNotifications": "None",
                        "digitalSignature": True
                    }, indent=2)
                },
                "url": {
                    "raw": "{{baseUrl}}/api/v1/covers/requirements",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "covers", "requirements"]
                }
            }
        })
        break

with open("backend/EasyClaim.postman_collection.json", "w") as f:
    json.dump(data, f, indent=4)
