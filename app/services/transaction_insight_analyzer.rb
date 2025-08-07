class TransactionInsightAnalyzer
  include ActiveModel::Model
  
  def initialize(user, transaction)
    @user = user
    @transaction = transaction
    @personality = user.financial_personality
    @openai_client = OpenAI::Client.new(access_token: Rails.application.credentials.openai_access_token)
  end
  
  def analyze_transaction
    return nil unless should_analyze?
    
    context = prepare_transaction_context
    analysis = analyze_with_ai(context)
    
    create_spending_insight(analysis) if analysis
  end
  
  private
  
  attr_reader :user, :transaction, :personality, :openai_client
  
  def should_analyze?
    # Only analyze expenses over a certain threshold or frequency
    amount = transaction.amount_money.abs
    
    # Analyze if:
    # 1. Large transaction (over $50)
    # 2. Frequent small transactions from same merchant
    # 3. Transaction during known emotional spending times
    amount > 50 || frequent_merchant_transaction? || emotional_spending_time?
  end
  
  def prepare_transaction_context
    recent_transactions = user.account_entries
                             .where(date: 7.days.ago..)
                             .where('amount_money < 0')
                             .includes(:merchant, :category)
    
    {
      transaction_amount: transaction.amount_money.abs,
      transaction_category: transaction.category&.name,
      transaction_merchant: transaction.merchant&.name,
      transaction_time: transaction.date,
      transaction_day_of_week: transaction.date.strftime('%A'),
      transaction_hour: transaction.date.hour,
      recent_spending: recent_transactions.sum(&:amount_money).abs,
      recent_similar_transactions: find_similar_recent_transactions,
      monthly_category_spending: calculate_monthly_category_spending,
      personality_type: personality.personality_type,
      spending_triggers: personality.spending_triggers,
      discipline_level: personality.discipline_level
    }
  end
  
  def analyze_with_ai(context)
    prompt = build_analysis_prompt(context)
    
    response = openai_client.chat(
      parameters: {
        model: "gpt-4",
        messages: [
          { role: "system", content: analysis_system_prompt },
          { role: "user", content: prompt }
        ],
        temperature: 0.3,
        max_tokens: 800
      }
    )
    
    JSON.parse(response.dig("choices", 0, "message", "content"))
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse transaction insight: #{e.message}"
    nil
  rescue => e
    Rails.logger.error "Transaction insight analysis error: #{e.message}"
    nil
  end
  
  def analysis_system_prompt
    <<~PROMPT
      You are an expert financial behavior analyst. Analyze individual transactions to identify spending patterns and provide insights.
      
      Respond with JSON containing:
      {
        "pattern_type": "one of: #{SpendingInsight::PATTERN_TYPES.join(', ')}",
        "emotional_context": "one of: #{SpendingInsight::EMOTIONAL_CONTEXTS.join(', ')} or null",
        "trigger_identification": ["array", "of", "triggers"],
        "ai_recommendation": "brief actionable advice",
        "confidence_score": 0-100,
        "requires_intervention": true/false
      }
      
      Focus on identifying:
      - Emotional spending patterns
      - Impulse purchases
      - Stress-related spending
      - Social spending influences
      - Habit-based purchases
      - Budget deviation patterns
      
      Consider the user's personality type and known triggers.
    PROMPT
  end
  
  def build_analysis_prompt(context)
    <<~PROMPT
      Analyze this transaction for a #{context[:personality_type]} personality:
      
      Transaction Details:
      - Amount: $#{context[:transaction_amount]}
      - Category: #{context[:transaction_category] || 'Unknown'}
      - Merchant: #{context[:transaction_merchant] || 'Unknown'}
      - Time: #{context[:transaction_time]} (#{context[:transaction_day_of_week]})
      - Hour: #{context[:transaction_hour]}:00
      
      Context:
      - Recent 7-day spending: $#{context[:recent_spending]}
      - Similar recent transactions: #{context[:recent_similar_transactions].count}
      - Monthly category spending: $#{context[:monthly_category_spending]}
      - Known spending triggers: #{context[:spending_triggers].join(', ')}
      - Discipline level: #{context[:discipline_level]}/10
      
      Identify any concerning patterns or triggers in this transaction.
    PROMPT
  end
  
  def create_spending_insight(analysis)
    user.spending_insights.create!(
      transaction: transaction,
      pattern_type: analysis['pattern_type'],
      emotional_context: analysis['emotional_context'],
      trigger_identification: analysis['trigger_identification'],
      ai_recommendation: analysis['ai_recommendation'],
      confidence_score: analysis['confidence_score']
    )
  rescue => e
    Rails.logger.error "Failed to create spending insight: #{e.message}"
    nil
  end
  
  def frequent_merchant_transaction?
    return false unless transaction.merchant
    
    # Check if user has made 3+ transactions at this merchant in the last week
    recent_merchant_count = user.account_entries
                               .where(merchant: transaction.merchant)
                               .where(date: 7.days.ago..)
                               .count
    
    recent_merchant_count >= 3
  end
  
  def emotional_spending_time?
    hour = transaction.date.hour
    day = transaction.date.strftime('%A')
    
    # Common emotional spending times:
    # - Late night (10 PM - 2 AM)
    # - Sunday evening (Sunday 6 PM - 10 PM) - "Sunday scaries"
    # - Friday evening (Friday 6 PM - 10 PM) - celebration/stress relief
    
    (hour >= 22 || hour <= 2) || 
    (day == 'Sunday' && hour >= 18 && hour <= 22) ||
    (day == 'Friday' && hour >= 18 && hour <= 22)
  end
  
  def find_similar_recent_transactions
    user.account_entries
        .where(date: 7.days.ago..)
        .where('amount_money < 0')
        .where(
          'category_id = ? OR merchant_id = ?',
          transaction.category_id,
          transaction.merchant_id
        )
        .where.not(id: transaction.id)
        .limit(5)
  end
  
  def calculate_monthly_category_spending
    return 0 unless transaction.category
    
    user.account_entries
        .where(category: transaction.category)
        .where(date: 1.month.ago..)
        .where('amount_money < 0')
        .sum(&:amount_money).abs
  end
end
