import json

with open("EasyClaim.postman_collection.json", "r") as f:
    pm = json.load(f)

openapi = {
    "openapi": "3.0.0",
    "info": {
        "title": "EasyClaim API",
        "version": "1.0.0",
        "description": "API documentation for the EasyClaim Platform"
    },
    "paths": {}
}

def process_items(items):
    for item in items:
        if "item" in item:
            process_items(item["item"])
        else:
            if "request" in item:
                req = item["request"]
                method = req["method"].lower()
                url_raw = req["url"]["raw"]
                
                # Replace {{baseUrl}} and clean up
                path = url_raw.replace("{{baseUrl}}", "").split("?")[0]
                
                # Replace {{claimId}} with {claimId}
                path = path.replace("{{claimId}}", "{claimId}")
                path = path.replace("{{tenantId}}", "{tenantId}")

                if path not in openapi["paths"]:
                    openapi["paths"][path] = {}
                
                parameters = []
                if "{claimId}" in path:
                    parameters.append({
                        "name": "claimId",
                        "in": "path",
                        "required": True,
                        "schema": {"type": "string"}
                    })
                if "{tenantId}" in path:
                    parameters.append({
                        "name": "tenantId",
                        "in": "path",
                        "required": True,
                        "schema": {"type": "string"}
                    })

                openapi["paths"][path][method] = {
                    "summary": item["name"],
                    "responses": {
                        "200": {"description": "Successful operation"}
                    }
                }
                if parameters:
                    openapi["paths"][path][method]["parameters"] = parameters

process_items(pm["item"])

with open("src/openapi.json", "w") as f:
    json.dump(openapi, f, indent=2)
