import re

with open('frontend/lib/providers/covers_provider.dart', 'r') as f:
    content = f.read()

# Fix parsing
old_parse = "final data = jsonDecode(response.body) as List;"
new_parse = "final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;\n        final data = (jsonResponse['policies'] ?? []) as List;"
content = content.replace(old_parse, new_parse)

old_market = "final data = jsonDecode(marketResponse.body) as List;"
new_market = "final jsonResponse = jsonDecode(marketResponse.body) as Map<String, dynamic>;\n        final data = (jsonResponse['catalog'] ?? []) as List;"
content = content.replace(old_market, new_market)

with open('frontend/lib/providers/covers_provider.dart', 'w') as f:
    f.write(content)
