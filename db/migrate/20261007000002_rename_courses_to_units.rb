class RenameCoursesToUnits < ActiveRecord::Migration[8.1]
  def up
    # Attach existing courses to a program first, while the table is still `courses`.
    add_reference :courses, :program, foreign_key: true

    # One fallback program per organization so no course is orphaned.
    execute(<<~SQL.squish)
      INSERT INTO programs (name, organization_id, kind, created_at, updated_at)
      SELECT organizations.name || ' Program', organizations.id, 0, NOW(), NOW()
      FROM organizations
      WHERE NOT EXISTS (SELECT 1 FROM programs WHERE programs.organization_id = organizations.id)
    SQL

    execute(<<~SQL.squish)
      UPDATE courses
      SET program_id = (SELECT id FROM programs WHERE programs.organization_id = courses.organization_id LIMIT 1)
    SQL

    change_column_null :courses, :program_id, false

    # Every unit belongs to a program; the direct organization column becomes redundant.
    remove_reference :courses, :organization, foreign_key: true

    rename_table :courses, :units
    rename_table :course_attendances, :unit_attendances
    rename_table :course_coverages, :unit_coverages

    rename_column :unit_attendances, :course_id, :unit_id
    rename_column :unit_coverages, :course_id, :unit_id

    # Single-column indexes are auto-renamed by rename_table/rename_column
    # (verified on PG); only the composite ones keep their old names.
    if index_name_exists?(:unit_attendances, "index_course_attendances_on_user_and_course")
      rename_index :unit_attendances,
        "index_course_attendances_on_user_and_course",
        "index_unit_attendances_on_user_and_unit"
    end
    if index_name_exists?(:unit_coverages, "index_course_coverages_on_course_and_content")
      rename_index :unit_coverages,
        "index_course_coverages_on_course_and_content",
        "index_unit_coverages_on_unit_and_content"
    end
  end

  def down
    if index_name_exists?(:unit_coverages, "index_unit_coverages_on_unit_and_content")
      rename_index :unit_coverages,
        "index_unit_coverages_on_unit_and_content",
        "index_course_coverages_on_course_and_content"
    end
    if index_name_exists?(:unit_attendances, "index_unit_attendances_on_user_and_unit")
      rename_index :unit_attendances,
        "index_unit_attendances_on_user_and_unit",
        "index_course_attendances_on_user_and_course"
    end

    rename_column :unit_coverages, :unit_id, :course_id
    rename_column :unit_attendances, :unit_id, :course_id

    rename_table :unit_coverages, :course_coverages
    rename_table :unit_attendances, :course_attendances
    rename_table :units, :courses

    add_reference :courses, :organization, null: true, foreign_key: true

    execute(<<~SQL.squish)
      UPDATE courses
      SET organization_id = (SELECT organization_id FROM programs WHERE programs.id = courses.program_id LIMIT 1)
    SQL

    change_column_null :courses, :organization_id, false
    remove_reference :courses, :program, foreign_key: true
  end
end
