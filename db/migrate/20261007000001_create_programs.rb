class CreatePrograms < ActiveRecord::Migration[8.1]
  def change
    create_table :programs do |t|
      t.string :name, null: false
      t.text :description
      t.references :organization, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0

      t.timestamps
    end

    add_index :programs, :kind
  end
end
