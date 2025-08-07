class BudgetRecommendationEngine
  include ActiveModel::Model
  
  def initialize(user)
    @user = user
    @personality = user.financial_personality
    @openai_client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
  end
  
  def generate_recommendations
    return unless @personality&.analysis_current?
    
    financial_data = prepare_financial_data
    
    # Generate three different budget scenarios
    recommendations = {
      conservative: generate_conservative_budget(financial_data),
      balanced: generate_balanced_budget(financial_data),
      aggressive: generate_aggressive_budget(financial_data)
    }
    
    # Use AI to refine recommendations based on personality
    ai_refined_recommendations = refine_with_ai(recommendations, financial_data)
    
    # Create or update budget recommendations
    save_recommendations(ai_refined_recommendations)
  end
  
  private
  
  attr_reader :user, :personality, :openai_client
  
  def prepare_financial_data
    recent_transactions = user.account_entries.where(date: 3.months.ago..)
    income_entries = recent_transactions.where('amount_money > 0')
    expense_entries = recent_transactions.where('amount_money < 0')
    
    {
      monthly_income: calculate_monthly_income(income_entries),
      monthly_expenses: calculate_monthly_expenses(expense_entries),
      expense_categories: categorize_expenses(expense_entries),
      savings_rate: calculate_current_savings_rate(income_entries, expense_entries),
      debt_payments: calculate_debt_payments,
      personality_type: personality.personality_type,
      risk_tolerance: personality.risk_tolerance,
      discipline_level: personality.discipline_level
    }
  end
  
  def generate_conservative_budget(data)
    # Conservative: High mandatory (60-70%), Low desires (10-20%), Moderate investments (20-30%)
    mandatory_base = 65
    desires_base = 15
    investment_base = 20
    
    # Adjust based on current situation
    mandatory_adjusted = [mandatory_base + (data[:debt_payments] > 0 ? 10 : 0), 80].min
    remaining = 100 - mandatory_adjusted
    desires_adjusted = [desires_base, remaining * 0.3].min
    investment_adjusted = remaining - desires_adjusted
    
    {
      type: 'conservative',
      mandatory: mandatory_adjusted,
      desires: desires_adjusted,
      investments: investment_adjusted,
      rationale: "Conservative approach focusing on financial security and debt reduction."
    }
  end
  
  def generate_balanced_budget(data)
    # Balanced: Moderate mandatory (50-60%), Moderate desires (20-30%), Moderate investments (20-30%)
    mandatory_base = 55
    desires_base = 25
    investment_base = 20
    
    # Adjust based on personality
    if personality.risk_tolerance > 6
      investment_base += 5
      desires_base -= 5
    end
    
    {
      type: 'balanced',
      mandatory: mandatory_base,
      desires: desires_base,
      investments: investment_base,
      rationale: "Balanced approach providing security while allowing for enjoyment and growth."
    }
  end
  
  def generate_aggressive_budget(data)
    # Aggressive: Lower mandatory (40-50%), Moderate desires (15-25%), High investments (30-40%)
    mandatory_base = 45
    desires_base = 20
    investment_base = 35
    
    # Adjust based on discipline level
    if personality.discipline_level < 6
      # Less aggressive if low discipline
      mandatory_base += 10
      investment_base -= 10
    end
    
    {
      type: 'aggressive',
      mandatory: mandatory_base,
      desires: desires_base,
      investments: investment_base,
      rationale: "Growth-focused approach maximizing long-term wealth building."
    }
  end
  
  def refine_with_ai(recommendations, financial_data)
    prompt = build_refinement_prompt(recommendations, financial_data)
    
    response = openai_client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          { role: "system", content: refinement_system_prompt },
          { role: "user", content: prompt }
        ],
        temperature: 0.2,
        max_tokens: 2000
      }
    )
    
    JSON.parse(response.dig("choices", 0, "message", "content"))
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI budget refinement: #{e.message}"
    recommendations
  end
  
  def refinement_system_prompt
    <<~PROMPT
      You are an expert financial advisor providing personalized budget recommendations.
      
      Refine the budget recommendations based on the user's personality, spending patterns, and financial situation.
      
      Respond with JSON containing three budget options:
      {
        "conservative": {
          "mandatory_allocation": 65,
          "desires_allocation": 15,
          "investment_allocation": 20,
          "rationale": "explanation",
          "category_breakdown": {"housing": 30, "food": 15, "transportation": 10, "utilities": 5, "debt": 5},
          "confidence_score": 85
        },
        "balanced": { ... },
        "aggressive": { ... }
      }
      
      Ensure allocations sum to 100% and consider:
      - User's personality type and risk tolerance
      - Current spending patterns
      - Discipline level for realistic targets
      - Life stage and financial goals
    PROMPT
  end
  
  def build_refinement_prompt(recommendations, data)
    <<~PROMPT
      User Profile:
      - Personality: #{data[:personality_type]}
      - Risk Tolerance: #{data[:risk_tolerance]}/10
      - Discipline Level: #{data[:discipline_level]}/10
      - Monthly Income: $#{data[:monthly_income]}
      - Monthly Expenses: $#{data[:monthly_expenses]}
      - Current Savings Rate: #{data[:savings_rate]}%
      
      Current Expense Categories:
      #{format_expense_categories(data[:expense_categories])}
      
      Initial Budget Recommendations:
      #{format_recommendations(recommendations)}
      
      Please refine these recommendations to be more personalized and realistic for this user.
    PROMPT
  end
  
  def save_recommendations(refined_recommendations)
    user.budget_recommendations.destroy_all # Clear old recommendations
    
    refined_recommendations.each do |type, data|
      user.budget_recommendations.create!(
        recommendation_type: type.to_s,
        mandatory_allocation: data['mandatory_allocation'],
        desires_allocation: data['desires_allocation'],
        investment_allocation: data['investment_allocation'],
        rationale: data['rationale'],
        category_breakdown: data['category_breakdown'],
        confidence_score: data['confidence_score'] || 75
      )
    end
  end
  
  def calculate_monthly_income(income_entries)
    return 0 if income_entries.empty?
    
    income_entries.sum(&:amount_money) / 3.0 # 3 months average
  end
  
  def calculate_monthly_expenses(expense_entries)
    return 0 if expense_entries.empty?
    
    expense_entries.sum(&:amount_money).abs / 3.0 # 3 months average
  end
  
  def categorize_expenses(expense_entries)
    expense_entries.group_by { |entry| entry.category&.name || 'Uncategorized' }
                   .transform_values { |entries| entries.sum(&:amount_money).abs / 3.0 }
                   .sort_by { |_, amount| -amount }
                   .first(10)
                   .to_h
  end
  
  def calculate_current_savings_rate(income_entries, expense_entries)
    income = income_entries.sum(&:amount_money)
    expenses = expense_entries.sum(&:amount_money).abs
    
    return 0 if income <= 0
    
    ((income - expenses) / income * 100).round(1)
  end
  
  def calculate_debt_payments
    # Look for debt-related categories or accounts
    debt_categories = user.categories.where(name: ['Debt Payment', 'Credit Card', 'Loan Payment'])
    debt_accounts = user.accounts.where(accountable_type: ['Loan', 'CreditCard'])
    
    debt_entries = user.account_entries.where(
      'category_id IN (?) OR account_id IN (?)',
      debt_categories.ids,
      debt_accounts.ids
    ).where(date: 1.month.ago..)
    
    debt_entries.sum(&:amount_money).abs
  end
  
  def format_expense_categories(categories)
    categories.map { |cat, amount| "#{cat}: $#{amount.round(2)}" }.join("\n")
  end
  
  def format_recommendations(recommendations)
    recommendations.map do |type, data|
      "#{type.capitalize}: #{data[:mandatory]}% mandatory, #{data[:desires]}% desires, #{data[:investments]}% investments"
    end.join("\n")
  end
end
