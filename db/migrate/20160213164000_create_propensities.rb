class CreatePropensities < ActiveRecord::Migration
  def change
    create_table :propensities do |t|
      t.integer :value
      t.integer :user_id
      t.integer :category_id

      t.timestamps null: false
    end
  end
end
