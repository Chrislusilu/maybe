class AiCoachingController < ApplicationController
  before_action :authenticate_user!
  
  def dashboard
    @personality = Current.user.financial_personality
    @recent_sessions = Current.user.ai_coaching_sessions.recent.limit(5)
    @active_budget = Current.user.budget_recommendations.active.first
    @spending_insights = Current.user.spending_insights.unacknowledged.limit(3)
    @spending_habits = Current.user.spending_habits.limit(5)
    
    # Generate daily checkin if needed
    if should_generate_daily_checkin?
      @daily_checkin = AiFinancialCoach.new(Current.user).daily_checkin
    end
  end
  
  def personality_analysis
    @personality = Current.user.financial_personality
    
    if @personality.nil? || !@personality.analysis_current?
      analyzer = FinancialPersonalityAnalyzer.new(Current.user)
      @personality = analyzer.analyze_and_update_personality
      
      if @personality.persisted?
        redirect_to ai_coaching_personality_analysis_path, notice: "Your financial personality has been analyzed!"
      else
        redirect_to ai_coaching_dashboard_path, alert: "Unable to analyze personality. Please ensure you have transaction data."
      end
    end
  end
  
  def budget_recommendations
    @recommendations = Current.user.budget_recommendations.includes(:user)
    @active_recommendation = @recommendations.active.first
    
    if @recommendations.empty? && Current.user.financial_personality&.analysis_current?
      engine = BudgetRecommendationEngine.new(Current.user)
      engine.generate_recommendations
      @recommendations = Current.user.budget_recommendations.reload
    end
  end
  
  def adopt_budget
    recommendation = Current.user.budget_recommendations.find(params[:id])
    recommendation.adopt!
    
    redirect_to ai_coaching_budget_recommendations_path, notice: "Budget recommendation adopted successfully!"
  rescue ActiveRecord::RecordNotFound
    redirect_to ai_coaching_budget_recommendations_path, alert: "Budget recommendation not found."
  end
  
  def purchase_guidance
    amount = params[:amount].to_f
    category = params[:category]
    emotional_context = params[:emotional_context]
    
    coach = AiFinancialCoach.new(Current.user)
    @guidance_session = coach.provide_purchase_guidance(
      amount, 
      category, 
      { emotional_state: emotional_context }
    )
    
    respond_to do |format|
      format.json { render json: { guidance: @guidance_session.ai_response } }
      format.html { redirect_to ai_coaching_dashboard_path }
    end
  end
  
  def crisis_intervention
    recent_spending = params[:spending_amount].to_f
    
    coach = AiFinancialCoach.new(Current.user)
    @crisis_session = coach.crisis_intervention(recent_spending)
    
    respond_to do |format|
      format.json { render json: { intervention: @crisis_session.ai_response } }
      format.html { redirect_to ai_coaching_dashboard_path }
    end
  end
  
  def acknowledge_insight
    insight = Current.user.spending_insights.find(params[:id])
    insight.acknowledge!
    
    redirect_to ai_coaching_dashboard_path, notice: "Insight acknowledged."
  rescue ActiveRecord::RecordNotFound
    redirect_to ai_coaching_dashboard_path, alert: "Insight not found."
  end
  
  def session_feedback
    session = Current.user.ai_coaching_sessions.find(params[:id])
    rating = params[:rating].to_i
    feedback = params[:feedback]
    
    session.record_feedback(rating, feedback)
    
    respond_to do |format|
      format.json { render json: { status: 'success' } }
      format.html { redirect_to ai_coaching_dashboard_path, notice: "Thank you for your feedback!" }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { error: 'Session not found' }, status: :not_found }
      format.html { redirect_to ai_coaching_dashboard_path, alert: "Session not found." }
    end
  end
  
  def regenerate_personality
    analyzer = FinancialPersonalityAnalyzer.new(Current.user)
    personality = analyzer.analyze_and_update_personality
    
    if personality.persisted?
      redirect_to ai_coaching_personality_analysis_path, notice: "Personality analysis updated!"
    else
      redirect_to ai_coaching_dashboard_path, alert: "Unable to update personality analysis."
    end
  end
  
  def regenerate_budget_recommendations
    engine = BudgetRecommendationEngine.new(Current.user)
    engine.generate_recommendations
    
    redirect_to ai_coaching_budget_recommendations_path, notice: "Budget recommendations updated!"
  end
  
  private
  
  def should_generate_daily_checkin?
    last_checkin = Current.user.ai_coaching_sessions
                             .where(session_type: 'daily_checkin')
                             .where(created_at: Date.current.beginning_of_day..)
                             .first
    
    last_checkin.nil?
  end
  
  def authenticate_user!
    redirect_to new_session_path unless Current.user
  end
end
