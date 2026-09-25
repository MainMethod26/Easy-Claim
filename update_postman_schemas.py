import json

with open("backend/EasyClaim.postman_collection.json", "r") as f:
    data = json.load(f)

for category in data["item"]:
    if category["name"] == "2. Policy Service":
        # Remove the generic one we added
        category["item"] = [item for item in category["item"] if item["name"] != "Submit Insurance Requirements"]
        
        category["item"].extend([{
            "name": "Submit Mobile Device Insurance",
            "request": {
                "method": "POST",
                "header": [{"key": "Content-Type", "value": "application/json"}],
                "body": {
                    "mode": "raw",
                    "raw": json.dumps({
                        "insurance_type": "Mobile Device Insurance",
                        "jurisdiction": "South Africa",
                        "regulatory_framework": ["FICA", "POPIA"],
                        "customer_identity_kyc": {
                            "full_name": "Sipho Nkosi",
                            "sa_id_number_or_passport": "8505125021087",
                            "proof_of_residence": "utility_bill_oct.pdf"
                        },
                        "asset_specific_details": {
                            "device_brand_and_model": "iPhone 14 Pro",
                            "serial_number": "SN123456789",
                            "imei_number": "353000000000000",
                            "purchase_proof": "retail_invoice.pdf"
                        },
                        "risk_and_underwriting": {
                            "cover_type": "All-Risk (Loss, Theft, Accidental Damage)",
                            "specified_accessories": ["AirPods Pro"],
                            "previous_claims_history": "False, no claims in past 3 years"
                        },
                        "financial_and_settlement": {
                            "bank_account_details": "Sipho Nkosi, Standard Bank, 051001, 123456789",
                            "debit_order_authorization": "EFT Mandate Confirmed"
                        }
                    }, indent=2)
                },
                "url": {
                    "raw": "{{baseUrl}}/api/v1/covers/requirements",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "covers", "requirements"]
                }
            }
        },
        {
            "name": "Submit Home Insurance",
            "request": {
                "method": "POST",
                "header": [{"key": "Content-Type", "value": "application/json"}],
                "body": {
                    "mode": "raw",
                    "raw": json.dumps({
                        "insurance_type": "Home Insurance (Building Structure & Contents)",
                        "jurisdiction": "South Africa",
                        "regulatory_framework": ["FICA", "POPIA", "Short-Term Insurance Act"],
                        "customer_identity_kyc": {
                            "full_name": "Sipho Nkosi",
                            "sa_id_number_or_passport": "8505125021087",
                            "tax_identification_number": "9876543210"
                        },
                        "property_and_asset_details": {
                            "physical_address": "123 Nelson Mandela Drive, Sandton, 2196",
                            "property_type": "Freehold",
                            "structure_replacement_value_zar": 2500000.00,
                            "contents_total_value_zar": 500000.00,
                            "security_features": ["Burglar bars", "24-hour armed response alarm system"]
                        },
                        "risk_and_compliance": {
                            "bond_holder_details": "Standard Bank (Lienholder)",
                            "compliance_certificates": ["Electrical Certificate of Compliance (COC)"],
                            "loss_history_3_years": "False, no loss records"
                        },
                        "financial_and_settlement": {
                            "premium_payment_method": "Debit order integration",
                            "excess_structure_agreement": "Voluntary excess R1000"
                        }
                    }, indent=2)
                },
                "url": {
                    "raw": "{{baseUrl}}/api/v1/covers/requirements",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "covers", "requirements"]
                }
            }
        },
        {
            "name": "Submit Motor Vehicle Insurance",
            "request": {
                "method": "POST",
                "header": [{"key": "Content-Type", "value": "application/json"}],
                "body": {
                    "mode": "raw",
                    "raw": json.dumps({
                        "insurance_type": "Motor Vehicle Insurance",
                        "jurisdiction": "South Africa",
                        "regulatory_framework": ["FICA", "POPIA", "National Road Traffic Act"],
                        "customer_identity_kyc": {
                            "full_name": "Sipho Nkosi",
                            "sa_id_number_or_passport": "8505125021087",
                            "drivers_license_details": {
                                "license_code": "Code B",
                                "issue_date": "2015-05-12",
                                "country_of_issuance": "South Africa"
                            }
                        },
                        "asset_specific_details": {
                            "vehicle_make_model_and_year": "VW Polo 2022",
                            "vin_number": "WVWZZZ6RZM",
                            "engine_number": "CJZ123456",
                            "registration_license_plate": "CA 123 456",
                            "estimated_annual_mileage": 15000,
                            "primary_parking_location_night": "Locked garage"
                        },
                        "risk_and_underwriting": {
                            "insurable_interest": "Financed",
                            "finance_house": "WesBank, Acc 123456789",
                            "tracking_device_installed": "True, Tracker",
                            "regular_driver_relationship": "Policyholder",
                            "claims_history_3_5_years": "Letter of no claim attached"
                        },
                        "legal_and_consent": {
                            "signed_schedule_consent": "Digital agreement to policy terms"
                        }
                    }, indent=2)
                },
                "url": {
                    "raw": "{{baseUrl}}/api/v1/covers/requirements",
                    "host": ["{{baseUrl}}"],
                    "path": ["api", "v1", "covers", "requirements"]
                }
            }
        }])
        break

with open("backend/EasyClaim.postman_collection.json", "w") as f:
    json.dump(data, f, indent=4)
