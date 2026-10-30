class AllowUnscheduledUnits < ActiveRecord::Migration[8.1]
  def up
    change_column_null :units, :starts_at, true
    change_column_null :units, :ends_at, true
  end

  def down
    change_column_null :units, :starts_at, false
    change_column_null :units, :ends_at, false
  end
end
