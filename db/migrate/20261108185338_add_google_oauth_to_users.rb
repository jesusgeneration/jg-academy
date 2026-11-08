class AddGoogleOauthToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_index :users, [ :provider, :uid ], unique: true
    add_check_constraint :users,
      "provider IS NULL AND uid IS NULL OR provider IS NOT NULL AND uid IS NOT NULL",
      name: "users_provider_uid_together"
  end

  def down
    remove_check_constraint :users, name: "users_provider_uid_together"
    remove_index :users, [ :provider, :uid ]
    remove_column :users, :uid
    remove_column :users, :provider
  end
end
