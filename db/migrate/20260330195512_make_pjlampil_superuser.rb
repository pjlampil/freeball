class MakePjlampilSuperuser < ActiveRecord::Migration[8.0]
  def up
    User.where(email: "pjlampil@gmail.com").update_all(superuser: true)
  end

  def down
    User.where(email: "pjlampil@gmail.com").update_all(superuser: false)
  end
end
