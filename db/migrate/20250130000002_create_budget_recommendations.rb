class CreateBudgetRecommendations < ActiveRecord::Migration[7.2]
  def change
    create_table :budget_recommendations, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :recommendation_type, null: false # conservative, balanced, aggressive
      t.decimal :mandatory_allocation, precision: 5, scale: 2 # percentage
      t.decimal :desires_allocation, precision: 5, scale: 2 # percentage  
      t.decimal :investment_allocation, precision: 5, scale: 2 # percentage
      t.decimal :confidence_score, precision: 5, scale: 2
      t.text :rationale # AI explanation for the recommendation
      t.text :category_breakdown # JSON of detailed category allocations
      t.boolean :is_active, default: false
      t.datetime :adopted_at
      t.timestamps
    end

    add_index :budget_recommendations, :user_id
    add_index :budget_recommendations, :recommendation_type
    add_index :budget_recommendations, [:user_id, :is_active]
  end
end
