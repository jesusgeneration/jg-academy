class CreateCourseAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :course_attendances do |t|
      t.references :user, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :course_attendances, [ :user_id, :course_id ], unique: true,
      name: "index_course_attendances_on_user_and_course"
  end
end
