class CreateAiCoachingSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_coaching_sessions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :session_type # daily_checkin, crisis_intervention, goal_review, etc.
      t.text :context_data # JSON of relevant user data for the session
      t.text :ai_response
      t.text :user_feedback
      t.integer :satisfaction_rating # 1-5 scale
      t.boolean :action_taken, default: false
      t.text :action_details
      t.timestamps
    end

    add_index :ai_coaching_sessions, :user_id
    add_index :ai_coaching_sessions, :session_type
    add_index :ai_coaching_sessions, [:user_id, :created_at]
  end
end
