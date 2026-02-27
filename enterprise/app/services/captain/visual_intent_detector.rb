class Captain::VisualIntentDetector
  # High-confidence visual keywords — these strongly signal image intent.
  # NOTE: "see" and "look" were deliberately EXCLUDED because they trigger
  # false positives on non-visual queries ("let me see your hours",
  # "I am looking for a price quote"). Only include words that unambiguously
  # signal a desire for images/visuals.
  VISUAL_KEYWORDS_EN = %w[photo picture image gallery portfolio review show].freeze
  VISUAL_KEYWORDS_TH = %w[รูป ภาพ ตัวอย่าง แกลเลอรี่ ผลงาน รีวิว].freeze
  ALL_KEYWORDS = (VISUAL_KEYWORDS_EN + VISUAL_KEYWORDS_TH).freeze

  def self.detected?(text)
    return false if text.blank?

    normalized = text.downcase
    ALL_KEYWORDS.any? { |kw| normalized.include?(kw) }
  end
end
