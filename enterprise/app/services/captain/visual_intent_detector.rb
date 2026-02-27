class Captain::VisualIntentDetector
  # High-confidence visual keywords — these strongly signal image intent.
  # NOTE: "see", "look", "show", and "review" were deliberately EXCLUDED because
  # they trigger false positives on non-visual queries ("let me see your hours",
  # "show me your schedule", "can I review my order?"). Only include words that
  # unambiguously signal a desire for images/visuals.
  # English uses word-boundary matching; Thai uses substring (no word boundaries in Thai script).
  VISUAL_KEYWORDS_EN = %w[photo picture image gallery portfolio].freeze
  VISUAL_KEYWORDS_TH = %w[รูป ภาพ ตัวอย่าง แกลเลอรี่ ผลงาน รีวิว].freeze

  def self.detected?(text)
    return false if text.blank?

    normalized = text.downcase
    VISUAL_KEYWORDS_EN.any? { |kw| normalized.match?(/\b#{Regexp.escape(kw)}\b/) } ||
      VISUAL_KEYWORDS_TH.any? { |kw| normalized.include?(kw) }
  end
end
