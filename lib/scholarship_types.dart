class ScholarshipTypes {
  static const Map<String, String> giftTypeOptions = {
    'Datu Pamulingan (IP Member)': 'ip_member',
    'Persons with Disability (PWD)': 'pwd',
  };

  static final Map<String, String> giftTypeLabelsByValue = Map.fromEntries(
    giftTypeOptions.entries.map((entry) => MapEntry(entry.value, entry.key)),
  );

  static const List<String> giftTypeLabels = [
    'Datu Pamulingan (IP Member)',
    'Persons with Disability (PWD)',
  ];

  static String giftTypeLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value.isEmpty) return '';
    if (giftTypeLabelsByValue.containsKey(value)) {
      return giftTypeLabelsByValue[value]!;
    }
    if (value.contains('ip') || value.contains('pamulingan')) {
      return 'Datu Pamulingan (IP Member)';
    }
    if (value.contains('pwd') || value.contains('disability')) {
      return 'Persons with Disability (PWD)';
    }
    return '';
  }

  static String giftTypePayload(String label) {
    final value = label.toLowerCase().trim();
    if (value.contains('pamulingan') || value.contains('ip member') || value == 'ip') {
      return 'ip_member';
    }
    if (value.contains('pwd') || value.contains('disability')) {
      return 'pwd';
    }
    return '';
  }

  static String normalizedGiftType(dynamic raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    if (value.isEmpty) return '';
    if (value.contains('pamulingan') ||
        value.contains('ip_member') ||
        value.contains('ip member') ||
        value == 'ip') {
      return 'ip_member';
    }
    if (value.contains('pwd') || value.contains('disability')) {
      return 'pwd';
    }
    return '';
  }
}
