class AiFinancialCoach
  include ActiveModel::Model
  
  def initialize(user)
    @user = user
    @personality = user.financial_personality
    @openai_client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
  end
  
  def daily_checkin
    context = prepare_daily_context
    coaching_response = generate_coaching_response('daily_checkin', context)
    
    create_coaching_session('daily_checkin', context, coaching_response)
  end
  
  def crisis_intervention(recent_spending)
    context = prepare_crisis_context(recent_spending)
    coaching_response = generate_coaching_response('crisis_intervention', context)
    
    create_coaching_session('crisis_intervention', context, coaching_response)
  end
  
  def goal_review
    context = prepare_goal_context
    coaching_response = generate_coaching_response('goal_review', context)
    
    create_coaching_session('goal_review', context, coaching_response)
  end
  
  def provide_purchase_guidance(amount, category, context = {})
    guidance_context = prepare_purchase_context(amount, category, context)
    coaching_response = generate_coaching_response('purchase_guidance', guidance_context)
    
    create_coaching_session('purchase_guidance', guidance_context, coaching_response)
  end
  
  private
  
  attr_reader :user, :personality, :openai_client
  
  def prepare_daily_context
    budget = user.budget_recommendations.active.first
    recent_spending = user.account_entries.where(date: 1.day.ago..Time.current)
    
    {
      personality_type: personality&.personality_type,
      discipline_level: personality&.discipline_level,
      recent_spending: recent_spending.sum(&:amount_money).abs,
      budget_status: calculate_budget_status(budget),
      spending_streak: calculate_spending_streak,
      upcoming_goals: user.goals&.active&.limit(3)
    }
  end
  
  def prepare_crisis_context(recent_spending)
    budget = user.budget_recommendations.active.first
    spending_insights = user.spending_insights.recent.limit(5)
    
    {
      personality_type: personality&.personality_type,
      discipline_level: personality&.discipline_level,
      crisis_spending: recent_spending,
      budget_impact: calculate_budget_impact(recent_spending, budget),
      recent_patterns: spending_insights.map(&:pattern_type),
      emotional_triggers: spending_insights.map(&:emotional_context).compact
    }
  end
  
  def prepare_goal_context
    goals = user.goals&.active
    recent_progress = calculate_recent_goal_progress
    
    {
      personality_type: personality&.personality_type,
      goals: goals&.map { |g| { name: g.name, target: g.target_amount, current: g.current_amount } },
      recent_progress: recent_progress,
      time_to_goals: calculate_time_to_goals(goals)
    }
  end
  
  def prepare_purchase_context(amount, category, context)
    budget = user.budget_recommendations.active.first
    category_spending = calculate_category_spending_this_month(category)
    
    {
      personality_type: personality&.personality_type,
      purchase_amount: amount,
      category: category,
      monthly_category_spending: category_spending,
      budget_remaining: calculate_category_budget_remaining(budget, category),
      similar_recent_purchases: find_similar_purchases(amount, category),
      emotional_context: context[:emotional_state],
      time_of_day: Time.current.hour,
      day_of_week: Time.current.strftime('%A')
    }
  end
  
  def generate_coaching_response(session_type, context)
    prompt = build_coaching_prompt(session_type, context)
    
    response = openai_client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          { role: "system", content: coaching_system_prompt(session_type) },
          { role: "user", content: prompt }
        ],
        temperature: 0.7,
        max_tokens: 800
      }
    )
    
    response.dig("choices", 0, "message", "content")
  rescue => e
    Rails.logger.error "AI coaching error: #{e.message}"
    fallback_response(session_type)
  end
  
  def coaching_system_prompt(session_type)
    base_prompt = <<~PROMPT
      You are a supportive, empathetic financial coach helping users build better money habits.
      
      Your personality:
      - Encouraging and non-judgmental
      - Practical and actionable
      - Understanding of human psychology
      - Focused on small, sustainable changes
      - Celebrates progress, no matter how small
      
      Guidelines:
      - Keep responses concise (2-3 sentences max for daily checkins)
      - Use encouraging, friendly language
      - Provide specific, actionable advice
      - Reference their personality type when relevant
      - Acknowledge emotions and stress around money
      - Focus on progress, not perfection
    PROMPT
    
    case session_type
    when 'daily_checkin'
      base_prompt + "\nFor daily check-ins: Provide a brief, encouraging message with one small actionable tip."
    when 'crisis_intervention'
      base_prompt + "\nFor crisis intervention: Be extra supportive, help them pause and reflect, offer immediate coping strategies."
    when 'goal_review'
      base_prompt + "\nFor goal reviews: Celebrate progress, adjust expectations if needed, provide motivation to continue."
    when 'purchase_guidance'
      base_prompt + "\nFor purchase guidance: Help them pause and consider if this aligns with their values and budget."
    else
      base_prompt
    end
  end
  
  def build_coaching_prompt(session_type, context)
    case session_type
    when 'daily_checkin'
      <<~PROMPT
        Daily check-in for a #{context[:personality_type]} personality:
        - Recent spending: $#{context[:recent_spending]}
        - Budget status: #{context[:budget_status]}
        - Spending streak: #{context[:spending_streak]} days
        - Discipline level: #{context[:discipline_level]}/10
        
        Provide an encouraging daily message with one actionable tip.
      PROMPT
    when 'crisis_intervention'
      <<~PROMPT
        Crisis intervention needed for a #{context[:personality_type]} personality:
        - Crisis spending: $#{context[:crisis_spending]}
        - Budget impact: #{context[:budget_impact]}
        - Recent patterns: #{context[:recent_patterns].join(', ')}
        - Emotional triggers: #{context[:emotional_triggers].join(', ')}
        - Discipline level: #{context[:discipline_level]}/10
        
        Provide supportive guidance to help them pause and recover.
      PROMPT
    when 'goal_review'
      <<~PROMPT
        Goal review for a #{context[:personality_type]} personality:
        - Goals: #{context[:goals]&.map { |g| "#{g[:name]}: #{g[:current]}/#{g[:target]}" }&.join(', ')}
        - Recent progress: #{context[:recent_progress]}
        
        Provide encouraging feedback and next steps.
      PROMPT
    when 'purchase_guidance'
      <<~PROMPT
        Purchase guidance for a #{context[:personality_type]} personality:
        - Purchase: $#{context[:purchase_amount]} in #{context[:category]}
        - Monthly category spending: $#{context[:monthly_category_spending]}
        - Budget remaining: $#{context[:budget_remaining]}
        - Emotional state: #{context[:emotional_context]}
        - Time: #{context[:time_of_day]}:00 on #{context[:day_of_week]}
        
        Help them make a mindful decision about this purchase.
      PROMPT
    end
  end
  
  def create_coaching_session(type, context, response)
    user.ai_coaching_sessions.create!(
      session_type: type,
      context_data: context.to_json,
      ai_response: response
    )
  end
  
  def calculate_budget_status(budget)
    return "No active budget" unless budget
    
    current_month_spending = user.account_entries
                                .where(date: Time.current.beginning_of_month..)
                                .where('amount_money < 0')
                                .sum(&:amount_money).abs
    
    monthly_income = user.account_entries
                        .where(date: 1.month.ago..)
                        .where('amount_money > 0')
                        .sum(&:amount_money) / 1.0
    
    return "Unable to calculate" if monthly_income <= 0
    
    budget_amount = monthly_income * (budget.desires_allocation / 100.0)
    remaining = budget_amount - current_month_spending
    
    if remaining > 0
      "#{((remaining / budget_amount) * 100).round}% budget remaining"
    else
      "#{((remaining.abs / budget_amount) * 100).round}% over budget"
    end
  end
  
  def calculate_spending_streak
    # Calculate days since last "bad" spending day
    recent_days = 30.days.ago..Time.current
    daily_spending = user.account_entries
                        .where(date: recent_days)
                        .where('amount_money < 0')
                        .group_by { |entry| entry.date.to_date }
                        .transform_values { |entries| entries.sum(&:amount_money).abs }
    
    # Define "good" spending day (could be based on budget)
    average_daily_spending = daily_spending.values.sum / daily_spending.size.to_f
    good_spending_threshold = average_daily_spending * 1.2
    
    streak = 0
    Date.current.downto(30.days.ago.to_date) do |date|
      daily_amount = daily_spending[date] || 0
      if daily_amount <= good_spending_threshold
        streak += 1
      else
        break
      end
    end
    
    streak
  end
  
  def fallback_response(session_type)
    case session_type
    when 'daily_checkin'
      "Great job checking in today! Remember, small consistent actions lead to big financial wins. What's one thing you can do today to move closer to your goals?"
    when 'crisis_intervention'
      "I understand this feels overwhelming right now. Take a deep breath. Every financial setback is temporary and a chance to learn. What's one small step you can take right now to feel more in control?"
    when 'goal_review'
      "Progress isn't always linear, and that's okay! Every step forward, no matter how small, is worth celebrating. What's working well for you right now?"
    else
      "You're doing great by staying engaged with your finances. Keep up the good work!"
    end
  end
  
  # Additional helper methods would go here...
  def calculate_budget_impact(spending, budget)
    "Moderate impact" # Simplified for now
  end
  
  def calculate_recent_goal_progress
    "Making steady progress" # Simplified for now
  end
  
  def calculate_time_to_goals(goals)
    {} # Simplified for now
  end
  
  def calculate_category_spending_this_month(category)
    0 # Simplified for now
  end
  
  def calculate_category_budget_remaining(budget, category)
    0 # Simplified for now
  end
  
  def find_similar_purchases(amount, category)
    [] # Simplified for now
  end
end
