class SpendingHabit < ApplicationRecord
  belongs_to :user
  
  validates :habit_type, presence: true
  validates :category, presence: true
  validates :average_amount, numericality: { greater_than: 0 }
  validates :frequency_per_week, numericality: { greater_than_or_equal_to: 0 }
  validates :current_streak, :longest_streak, numericality: { greater_than_or_equal_to: 0 }
  
  scope :positive_habits, -> { where(is_positive_habit: true) }
  scope :negative_habits, -> { where(is_positive_habit: false) }
  scope :frequent, -> { where('frequency_per_week >= ?', 3) }
  
  def ai_suggestions
    JSON.parse(super || '[]')
  end
  
  def ai_suggestions=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  def update_streak!(occurred_today)
    if occurred_today
      if is_positive_habit?
        self.current_streak += 1
        self.longest_streak = [longest_streak, current_streak].max
      else
        self.current_streak = 0 # Reset streak for negative habits
      end
    else
      if is_positive_habit?
        self.current_streak = 0 # Reset streak if positive habit was missed
      else
        self.current_streak += 1 # Increase streak for avoiding negative habit
        self.longest_streak = [longest_streak, current_streak].max
      end
    end
    
    self.last_occurrence_at = Time.current if occurred_today
    save!
  end
  
  def weekly_cost
    average_amount * frequency_per_week
  end
  
  def monthly_cost
    weekly_cost * 4.33 # Average weeks per month
  end
  
  def yearly_cost
    weekly_cost * 52
  end
  
  def habit_strength
    # Calculate habit strength based on consistency and streak
    consistency_score = [frequency_per_week / 7.0, 1.0].min * 100
    streak_score = [current_streak / 30.0, 1.0].min * 100
    
    (consistency_score + streak_score) / 2
  end
end
