class AddValidUntilToUnits < ActiveRecord::Migration[8.1]
  def change
    add_column :units, :valid_until, :date
  end
end
