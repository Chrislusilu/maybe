class AiNotification < ApplicationRecord
  belongs_to :user
  
  validates :notification_type, :title, :message, presence: true
  validates :priority, inclusion: { in: %w[low medium high urgent] }
  
  NOTIFICATION_TYPES = %w[
    spending_alert
    goal_progress
    habit_reminder
    budget_warning
    achievement_unlock
    coaching_suggestion
    crisis_alert
    celebration
    educational_tip
  ].freeze
  
  validates :notification_type, inclusion: { in: NOTIFICATION_TYPES }
  
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :urgent, -> { where(priority: 'urgent') }
  scope :scheduled, -> { where.not(scheduled_for: nil) }
  scope :ready_to_send, -> { where('scheduled_for IS NULL OR scheduled_for <= ?', Time.current) }
  
  def action_data
    JSON.parse(super || '{}')
  end
  
  def action_data=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  def mark_as_read!
    update!(read: true, read_at: Time.current)
  end
  
  def urgent?
    priority == 'urgent'
  end
  
  def high_priority?
    priority.in?(['high', 'urgent'])
  end
  
  def scheduled?
    scheduled_for.present?
  end
  
  def ready_to_send?
    scheduled_for.nil? || scheduled_for <= Time.current
  end
end
