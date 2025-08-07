class AiCoachingSession < ApplicationRecord
  belongs_to :user
  
  validates :session_type, presence: true
  validates :ai_response, presence: true
  validates :satisfaction_rating, inclusion: { in: 1..5 }, allow_nil: true
  
  SESSION_TYPES = %w[
    daily_checkin
    crisis_intervention
    goal_review
    purchase_guidance
    habit_coaching
    motivation_boost
    educational_content
    celebration
  ].freeze
  
  validates :session_type, inclusion: { in: SESSION_TYPES }
  
  scope :recent, -> { where(created_at: 1.week.ago..) }
  scope :by_type, ->(type) { where(session_type: type) }
  scope :with_feedback, -> { where.not(satisfaction_rating: nil) }
  scope :positive_feedback, -> { where(satisfaction_rating: 4..5) }
  
  def context_data
    JSON.parse(super || '{}')
  end
  
  def context_data=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  def record_feedback(rating, feedback = nil)
    update!(
      satisfaction_rating: rating,
      user_feedback: feedback
    )
  end
  
  def record_action_taken(details)
    update!(
      action_taken: true,
      action_details: details
    )
  end
  
  def positive_feedback?
    satisfaction_rating && satisfaction_rating >= 4
  end
  
  def crisis_session?
    session_type == 'crisis_intervention'
  end
  
  def daily_session?
    session_type == 'daily_checkin'
  end
end
