class CreateJuleicaRequirements < ActiveRecord::Migration[8.1]
  def change
    create_table :juleica_requirements do |t|
      t.string :name, null: false
      t.text :description
      t.decimal :required_hours, precision: 6, scale: 2, null: false

      t.timestamps
    end

    add_index :juleica_requirements, :name, unique: true
    add_check_constraint :juleica_requirements, "required_hours > 0",
      name: "juleica_requirements_required_hours_positive"
  end
end
