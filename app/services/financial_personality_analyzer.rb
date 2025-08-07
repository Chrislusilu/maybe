class FinancialPersonalityAnalyzer
  include ActiveModel::Model
  
  def initialize(user)
    @user = user
    @openai_client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
  end
  
  def analyze_and_update_personality
    return unless @user.account_entries.exists?
    
    transaction_data = prepare_transaction_data
    personality_analysis = analyze_with_ai(transaction_data)
    
    update_personality_profile(personality_analysis)
  end
  
  private
  
  attr_reader :user, :openai_client
  
  def prepare_transaction_data
    # Get last 6 months of transactions
    recent_transactions = user.account_entries
                             .includes(:account, :category, :merchant)
                             .where(date: 6.months.ago..)
                             .order(:date)
    
    {
      transaction_count: recent_transactions.count,
      total_spending: recent_transactions.sum(&:amount_money).abs,
      categories: categorize_spending(recent_transactions),
      timing_patterns: analyze_timing_patterns(recent_transactions),
      amount_patterns: analyze_amount_patterns(recent_transactions),
      merchant_patterns: analyze_merchant_patterns(recent_transactions)
    }
  end
  
  def analyze_with_ai(data)
    prompt = build_analysis_prompt(data)
    
    response = openai_client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: system_prompt
          },
          {
            role: "user", 
            content: prompt
          }
        ],
        temperature: 0.3,
        max_tokens: 1500
      }
    )
    
    JSON.parse(response.dig("choices", 0, "message", "content"))
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI response: #{e.message}"
    default_analysis
  end
  
  def system_prompt
    <<~PROMPT
      You are an expert financial psychologist analyzing spending patterns to determine personality types and provide insights.
      
      Analyze the user's transaction data and respond with a JSON object containing:
      {
        "personality_type": "one of: #{FinancialPersonality::PERSONALITY_TYPES.join(', ')}",
        "risk_tolerance": 1-10,
        "discipline_level": 1-10,
        "spending_triggers": ["array", "of", "triggers"],
        "financial_traumas": ["array", "of", "trauma", "indicators"],
        "lifestyle_preferences": {"key": "value", "preferences": "object"},
        "confidence_score": 0-100,
        "analysis_summary": "Brief explanation of the analysis"
      }
      
      Focus on:
      - Spending consistency vs. volatility
      - Emotional spending patterns
      - Risk-taking behavior
      - Planning vs. impulsive behavior
      - Response to financial stress
      - Social spending influences
    PROMPT
  end
  
  def build_analysis_prompt(data)
    <<~PROMPT
      Analyze this user's financial behavior:
      
      Transaction Summary:
      - Total transactions: #{data[:transaction_count]}
      - Total spending: $#{data[:total_spending]}
      
      Category Breakdown:
      #{format_category_data(data[:categories])}
      
      Timing Patterns:
      #{format_timing_data(data[:timing_patterns])}
      
      Amount Patterns:
      #{format_amount_data(data[:amount_patterns])}
      
      Merchant Patterns:
      #{format_merchant_data(data[:merchant_patterns])}
      
      Please provide a comprehensive financial personality analysis.
    PROMPT
  end
  
  def update_personality_profile(analysis)
    personality = user.financial_personality || user.build_financial_personality
    
    personality.update!(
      personality_type: analysis['personality_type'],
      risk_tolerance: analysis['risk_tolerance'],
      discipline_level: analysis['discipline_level'],
      spending_triggers: analysis['spending_triggers'],
      financial_traumas: analysis['financial_traumas'],
      lifestyle_preferences: analysis['lifestyle_preferences'],
      confidence_score: analysis['confidence_score'],
      ai_analysis_summary: analysis['analysis_summary'],
      last_analyzed_at: Time.current
    )
    
    personality
  end
  
  def categorize_spending(transactions)
    transactions.group_by(&:category)
               .transform_values { |txns| txns.sum(&:amount_money).abs }
               .sort_by { |_, amount| -amount }
               .first(10)
               .to_h
  end
  
  def analyze_timing_patterns(transactions)
    {
      weekday_spending: transactions.group_by { |t| t.date.strftime('%A') }
                                  .transform_values { |txns| txns.sum(&:amount_money).abs },
      monthly_patterns: transactions.group_by { |t| t.date.beginning_of_month }
                                  .transform_values { |txns| txns.sum(&:amount_money).abs }
    }
  end
  
  def analyze_amount_patterns(transactions)
    amounts = transactions.map { |t| t.amount_money.abs }
    
    {
      average_transaction: amounts.sum / amounts.size,
      median_transaction: amounts.sort[amounts.size / 2],
      large_purchases: amounts.count { |a| a > amounts.sum / amounts.size * 3 },
      small_frequent: amounts.count { |a| a < 50 }
    }
  end
  
  def analyze_merchant_patterns(transactions)
    transactions.group_by(&:merchant)
               .transform_values { |txns| { count: txns.size, total: txns.sum(&:amount_money).abs } }
               .sort_by { |_, data| -data[:total] }
               .first(5)
               .to_h
  end
  
  def format_category_data(categories)
    categories.map { |cat, amount| "#{cat&.name || 'Uncategorized'}: $#{amount}" }.join("\n")
  end
  
  def format_timing_data(timing)
    timing.map { |key, data| "#{key}: #{data}" }.join("\n")
  end
  
  def format_amount_data(amounts)
    amounts.map { |key, value| "#{key}: #{value}" }.join("\n")
  end
  
  def format_merchant_data(merchants)
    merchants.map { |merchant, data| "#{merchant&.name || 'Unknown'}: #{data[:count]} transactions, $#{data[:total]}" }.join("\n")
  end
  
  def default_analysis
    {
      'personality_type' => 'balanced_planner',
      'risk_tolerance' => 5,
      'discipline_level' => 5,
      'spending_triggers' => [],
      'financial_traumas' => [],
      'lifestyle_preferences' => {},
      'confidence_score' => 50,
      'analysis_summary' => 'Default analysis - insufficient data for AI analysis'
    }
  end
end
