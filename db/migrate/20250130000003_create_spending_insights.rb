class CreateSpendingInsights < ActiveRecord::Migration[7.2]
  def change
    create_table :spending_insights, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :transaction, null: true, foreign_key: { to_table: :account_entries }, type: :uuid
      t.string :pattern_type, null: false # emotional_spending, impulse, stress, celebration, etc.
      t.string :emotional_context # happy, stressed, bored, anxious, etc.
      t.text :trigger_identification # JSON array of identified triggers
      t.text :ai_recommendation # AI-generated advice
      t.decimal :confidence_score, precision: 5, scale: 2
      t.boolean :user_acknowledged, default: false
      t.datetime :acknowledged_at
      t.timestamps
    end

    add_index :spending_insights, :user_id
    add_index :spending_insights, :pattern_type
    add_index :spending_insights, :emotional_context
    add_index :spending_insights, [:user_id, :created_at]
  end
end
