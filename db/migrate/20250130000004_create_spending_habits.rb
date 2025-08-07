class CreateSpendingHabits < ActiveRecord::Migration[7.2]
  def change
    create_table :spending_habits, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :habit_type, null: false # daily_coffee, lunch_out, impulse_shopping, etc.
      t.string :category # food, entertainment, shopping, etc.
      t.decimal :average_amount, precision: 10, scale: 2
      t.integer :frequency_per_week, default: 0
      t.integer :current_streak, default: 0
      t.integer :longest_streak, default: 0
      t.datetime :last_occurrence_at
      t.boolean :is_positive_habit, default: true
      t.text :ai_suggestions # JSON array of improvement suggestions
      t.timestamps
    end

    add_index :spending_habits, :user_id
    add_index :spending_habits, :habit_type
    add_index :spending_habits, :is_positive_habit
  end
end
