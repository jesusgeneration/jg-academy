class RealignRolesToOrganizationMemberships < ActiveRecord::Migration[8.1]
  def up
    add_column :organization_memberships, :role, :integer, default: 0, null: false

    # users.role: participant 0 | organiser 1 | admin 2  ->  user 0 | admin 1
    execute <<~SQL
      UPDATE users SET role = CASE WHEN role = 2 THEN 1 ELSE 0 END
    SQL
  end

  def down
    # Best-effort inverse: admins keep the old admin value; everyone else
    # becomes a plain participant. Organiser rights cannot be restored from
    # memberships alone.
    execute <<~SQL
      UPDATE users SET role = CASE WHEN role = 1 THEN 2 ELSE 0 END
    SQL

    remove_column :organization_memberships, :role
  end
end
