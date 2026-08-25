class CreateCourseRequirements < ActiveRecord::Migration[8.1]
  def change
    create_table :course_requirements do |t|
      t.references :course, null: false, foreign_key: true
      t.references :juleica_requirement, null: false, foreign_key: true
      t.decimal :hours, precision: 6, scale: 2, null: false

      t.timestamps
    end

    add_index :course_requirements, [ :course_id, :juleica_requirement_id ], unique: true,
      name: "index_course_requirements_on_course_and_requirement"
    add_check_constraint :course_requirements, "hours > 0",
      name: "course_requirements_hours_positive"
  end
end
