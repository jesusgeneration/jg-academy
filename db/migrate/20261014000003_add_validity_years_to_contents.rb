class AddValidityYearsToContents < ActiveRecord::Migration[8.1]
  def change
    add_column :contents, :validity_years, :integer
  end
end
