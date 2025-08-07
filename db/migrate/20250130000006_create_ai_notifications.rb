class CreateAiNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_notifications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :notification_type, null: false # spending_alert, goal_progress, habit_reminder, etc.
      t.string :title, null: false
      t.text :message, null: false
      t.string :priority, default: 'medium' # low, medium, high, urgent
      t.text :action_data # JSON data for any actions the notification might trigger
      t.boolean :read, default: false
      t.datetime :read_at
      t.datetime :scheduled_for # For future notifications
      t.timestamps
    end

    add_index :ai_notifications, :user_id
    add_index :ai_notifications, :notification_type
    add_index :ai_notifications, :priority
    add_index :ai_notifications, [:user_id, :read]
    add_index :ai_notifications, :scheduled_for
  end
end
