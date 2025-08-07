class CreateFinancialPersonalities < ActiveRecord::Migration[7.2]
  def change
    create_table :financial_personalities, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :personality_type, null: false
      t.integer :risk_tolerance, default: 5 # 1-10 scale
      t.integer :discipline_level, default: 5 # 1-10 scale
      t.text :spending_triggers # JSON array of trigger types
      t.text :financial_traumas # JSON array of trauma indicators
      t.text :lifestyle_preferences # JSON object of preferences
      t.decimal :confidence_score, precision: 5, scale: 2, default: 0.0
      t.text :ai_analysis_summary
      t.datetime :last_analyzed_at
      t.timestamps
    end

    add_index :financial_personalities, :user_id, unique: true
    add_index :financial_personalities, :personality_type
    add_index :financial_personalities, :last_analyzed_at
  end
end
