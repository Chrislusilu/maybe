class FinancialPersonality < ApplicationRecord
  belongs_to :user
  
  validates :personality_type, presence: true
  validates :risk_tolerance, inclusion: { in: 1..10 }
  validates :discipline_level, inclusion: { in: 1..10 }
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  # Personality types based on research
  PERSONALITY_TYPES = %w[
    conservative_saver
    balanced_planner  
    growth_seeker
    impulsive_spender
    anxious_avoider
    social_spender
    goal_oriented
    lifestyle_focused
  ].freeze
  
  validates :personality_type, inclusion: { in: PERSONALITY_TYPES }
  
  # JSON accessors for complex data
  def spending_triggers
    JSON.parse(super || '[]')
  end
  
  def spending_triggers=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  def financial_traumas
    JSON.parse(super || '[]')
  end
  
  def financial_traumas=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  def lifestyle_preferences
    JSON.parse(super || '{}')
  end
  
  def lifestyle_preferences=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  # Helper methods for personality insights
  def risk_averse?
    risk_tolerance <= 3
  end
  
  def high_discipline?
    discipline_level >= 7
  end
  
  def needs_frequent_coaching?
    discipline_level <= 4 || spending_triggers.include?('emotional_spending')
  end
  
  def analysis_current?
    last_analyzed_at && last_analyzed_at > 1.week.ago
  end
end
