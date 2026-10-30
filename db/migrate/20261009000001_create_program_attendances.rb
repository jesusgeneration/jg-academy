class CreateProgramAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :program_attendances do |t|
      t.references :user, null: false, foreign_key: true
      t.references :program, null: false, foreign_key: true
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :program_attendances, %i[user_id program_id], unique: true
  end
end
