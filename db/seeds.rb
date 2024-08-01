# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
User.create!([
  {email: "matt@mutter.com", password_digest: "$2a$12$iHFu.P.pWEKpYJ9lNuDd1u.eRIXcdtzk7If.mr1Eqau7Ut6mJGHTi", firstname: "Matt", lastname: "Mutter", username: "MassMutter"},
  {email: "test@tester.com", password_digest: "$2a$12$.09q0TaFul54FN1hOmM5JeJbrlKb4OnqFvhiWt6Yoy5R2IISCpW9K", firstname: "Testy", lastname: "Testington", username: "TryoutKings"}
])