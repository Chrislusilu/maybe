class SpendingInsight < ApplicationRecord
  belongs_to :user
  belongs_to :transaction, class_name: 'Account::Entry', optional: true
  
  validates :pattern_type, presence: true
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  PATTERN_TYPES = %w[
    emotional_spending
    impulse_purchase
    stress_spending
    celebration_spending
    social_spending
    subscription_creep
    lifestyle_inflation
    budget_drift
    seasonal_pattern
    weekend_splurge
  ].freeze
  
  EMOTIONAL_CONTEXTS = %w[
    happy
    stressed
    bored
    anxious
    excited
    sad
    frustrated
    celebratory
    peer_pressure
    routine
  ].freeze
  
  validates :pattern_type, inclusion: { in: PATTERN_TYPES }
  validates :emotional_context, inclusion: { in: EMOTIONAL_CONTEXTS }, allow_blank: true
  
  scope :unacknowledged, -> { where(user_acknowledged: false) }
  scope :recent, -> { where(created_at: 1.week.ago..) }
  scope :by_pattern, ->(pattern) { where(pattern_type: pattern) }
  
  def trigger_identification
    JSON.parse(super || '[]')
  end
  
  def trigger_identification=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  def acknowledge!
    update!(user_acknowledged: true, acknowledged_at: Time.current)
  end
  
  def high_confidence?
    confidence_score >= 70
  end
  
  def requires_intervention?
    pattern_type.in?(['emotional_spending', 'impulse_purchase', 'stress_spending']) && 
    high_confidence?
  end
end
