class AiPersonalityAnalysisJob < ApplicationJob
  queue_as :default
  
  def perform(user_id)
    user = User.find(user_id)
    return unless user.account_entries.exists?
    
    # Analyze personality
    analyzer = FinancialPersonalityAnalyzer.new(user)
    personality = analyzer.analyze_and_update_personality
    
    return unless personality&.persisted?
    
    # Generate budget recommendations if personality analysis was successful
    if personality.analysis_current?
      engine = BudgetRecommendationEngine.new(user)
      engine.generate_recommendations
    end
    
    # Generate daily coaching session
    coach = AiFinancialCoach.new(user)
    coach.daily_checkin
    
  rescue => e
    Rails.logger.error "AI Personality Analysis Job failed for user #{user_id}: #{e.message}"
    raise e
  end
end
