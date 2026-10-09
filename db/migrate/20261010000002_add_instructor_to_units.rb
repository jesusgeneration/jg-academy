class AddInstructorToUnits < ActiveRecord::Migration[8.1]
  def change
    add_reference :units, :instructor, foreign_key: { to_table: :users }, index: true
  end
end
