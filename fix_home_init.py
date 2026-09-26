import re

with open('frontend/lib/providers/home_screen_provider.dart', 'r') as f:
    content = f.read()

new_constructor = """  HomeScreenProvider() {
    _data = HomeScreenData(
      userId: 'usr_load',
      userName: 'Loading...',
      welcomeMessage: '',
      activeClaims: [],
      mostlyVisited: [],
      recentActivities: [],
      notifications: [],
      summaryStages: [],
      lastRefreshed: DateTime.now(),
    );
    _initSampleData();
  }"""

content = re.sub(r"  HomeScreenProvider\(\) {\n    _initSampleData\(\);\n  }", new_constructor, content)

with open('frontend/lib/providers/home_screen_provider.dart', 'w') as f:
    f.write(content)

