class TransactionInsightJob < ApplicationJob
  queue_as :default
  
  def perform(transaction_id)
    transaction = Account::Entry.find(transaction_id)
    user = transaction.account.family.users.first # Assuming single user per family for now
    
    return unless user.financial_personality&.analysis_current?
    return if transaction.amount_money >= 0 # Only analyze expenses
    
    analyzer = TransactionInsightAnalyzer.new(user, transaction)
    insight = analyzer.analyze_transaction
    
    # Check if this triggers a crisis intervention
    if insight&.requires_intervention?
      coach = AiFinancialCoach.new(user)
      coach.crisis_intervention(transaction.amount_money.abs)
    end
    
  rescue => e
    Rails.logger.error "Transaction Insight Job failed for transaction #{transaction_id}: #{e.message}"
    # Don't re-raise to avoid blocking transaction processing
  end
end
