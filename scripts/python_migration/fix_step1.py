import re

with open('lib/widgets/claims_wizard_modal.dart', 'r') as f:
    content = f.read()

old_step1 = """  // STEP 1: Identify Claim Category
  Widget _buildStep1Category() {
    final categories = ClaimCategories.allCategories;
    final selected = _provider.selectedCategory ?? categories.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What type of claim are you making today?',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        const SizedBox(height: 18),

        // Category Cards Grid
        ...categories.map((cat) {"""

new_step1 = """  // STEP 1: Identify Claim Category
  Widget _buildStep1Category() {
    final categories = ClaimCategories.allCategories;
    final selected = _provider.selectedCategory ?? categories.first;
    
    // If we came from a pre-filled active policy, don't ask dumb questions, just show what they have active.
    final displayCategories = widget.initialCategory != null 
        ? [selected] 
        : categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.initialCategory != null ? 'Confirm Claim Intake' : 'What type of claim are you making today?',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        const SizedBox(height: 18),

        // Category Cards Grid
        ...displayCategories.map((cat) {"""

content = content.replace(old_step1, new_step1)

with open('lib/widgets/claims_wizard_modal.dart', 'w') as f:
    f.write(content)

