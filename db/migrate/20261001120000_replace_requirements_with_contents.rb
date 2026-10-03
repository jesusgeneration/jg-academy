class ReplaceRequirementsWithContents < ActiveRecord::Migration[8.1]
  def up
    drop_table :course_requirements
    drop_table :juleica_requirements

    create_table :contents do |t|
      t.references :parent, foreign_key: { to_table: :contents }, index: true
      t.string :title, null: false
      t.integer :content_type, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :contents, :content_type
    add_index :contents, :position

    create_table :course_coverages do |t|
      t.references :course, null: false, foreign_key: true
      t.references :content, null: false, foreign_key: true

      t.timestamps
    end

    add_index :course_coverages, [ :course_id, :content_id ], unique: true,
      name: "index_course_coverages_on_course_and_content"
  end

  def down
    drop_table :course_coverages
    drop_table :contents

    create_table :juleica_requirements do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :required_hours, precision: 6, scale: 2, null: false

      t.timestamps
    end

    add_index :juleica_requirements, :name, unique: true
    add_check_constraint :juleica_requirements, "required_hours > 0",
      name: "juleica_requirements_required_hours_positive"

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
