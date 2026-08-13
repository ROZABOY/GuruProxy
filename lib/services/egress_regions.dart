/// Common Psiphon egress region codes. Empty / "auto" = let tunnel-core pick.
class EgressRegions {
  static const auto = 'auto';

  static const choices = <(String code, String label)>[
    ('auto', 'Auto (best available)'),
    ('US', 'United States'),
    ('GB', 'United Kingdom'),
    ('DE', 'Germany'),
    ('NL', 'Netherlands'),
    ('FR', 'France'),
    ('CA', 'Canada'),
    ('JP', 'Japan'),
    ('SG', 'Singapore'),
    ('IN', 'India'),
    ('AU', 'Australia'),
    ('BR', 'Brazil'),
    ('ES', 'Spain'),
    ('IT', 'Italy'),
    ('SE', 'Sweden'),
    ('CH', 'Switzerland'),
    ('AT', 'Austria'),
    ('BE', 'Belgium'),
    ('PL', 'Poland'),
    ('RO', 'Romania'),
    ('HK', 'Hong Kong'),
    ('KR', 'South Korea'),
    ('TW', 'Taiwan'),
    ('AE', 'United Arab Emirates'),
    ('IS', 'Iceland'),
    ('NO', 'Norway'),
    ('DK', 'Denmark'),
    ('FI', 'Finland'),
    ('IE', 'Ireland'),
    ('PT', 'Portugal'),
    ('CZ', 'Czechia'),
    ('HU', 'Hungary'),
    ('BG', 'Bulgaria'),
    ('SK', 'Slovakia'),
    ('SI', 'Slovenia'),
    ('HR', 'Croatia'),
    ('RS', 'Serbia'),
    ('UA', 'Ukraine'),
    ('TR', 'Türkiye'),
    ('IL', 'Israel'),
    ('ZA', 'South Africa'),
    ('AR', 'Argentina'),
    ('CL', 'Chile'),
    ('CO', 'Colombia'),
    ('MX', 'Mexico'),
    ('NZ', 'New Zealand'),
    ('MY', 'Malaysia'),
    ('TH', 'Thailand'),
    ('ID', 'Indonesia'),
    ('PH', 'Philippines'),
    ('VN', 'Vietnam'),
  ];

  static String labelFor(String code) {
    final c = code.trim().isEmpty ? auto : code.trim();
    for (final e in choices) {
      if (e.$1 == c) return e.$2;
    }
    return c.toUpperCase();
  }

  static String normalize(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty || v.toLowerCase() == 'auto') return auto;
    return v.toUpperCase();
  }

  /// Value written to tunnel-core config (empty = Auto).
  static String toConfigValue(String uiValue) {
    final n = normalize(uiValue);
    return n == auto ? '' : n;
  }
}
