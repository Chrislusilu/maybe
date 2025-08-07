class BudgetRecommendation < ApplicationRecord
  belongs_to :user
  
  validates :recommendation_type, presence: true, inclusion: { in: %w[conservative balanced aggressive] }
  validates :mandatory_allocation, :desires_allocation, :investment_allocation, 
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :confidence_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  validate :allocations_sum_to_100
  
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(recommendation_type: type) }
  
  def category_breakdown
    JSON.parse(super || '{}')
  end
  
  def category_breakdown=(value)
    super(value.is_a?(String) ? value : value.to_json)
  end
  
  def adopt!
    transaction do
      # Deactivate other recommendations for this user
      user.budget_recommendations.update_all(is_active: false)
      
      # Activate this recommendation
      update!(is_active: true, adopted_at: Time.current)
    end
  end
  
  def total_allocation
    mandatory_allocation + desires_allocation + investment_allocation
  end
  
  def conservative?
    recommendation_type == 'conservative'
  end
  
  def balanced?
    recommendation_type == 'balanced'
  end
  
  def aggressive?
    recommendation_type == 'aggressive'
  end
  
  private
  
  def allocations_sum_to_100
    return unless mandatory_allocation && desires_allocation && investment_allocation
    
    total = total_allocation
    unless (99.0..101.0).cover?(total) # Allow for small rounding differences
      errors.add(:base, "Budget allocations must sum to 100% (currently #{total}%)")
    end
  end
end
