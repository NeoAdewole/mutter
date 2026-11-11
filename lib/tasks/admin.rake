namespace :admin do
  desc 'Make an existing user an admin: bin/rails "admin:grant[someone@example.com]" (email or username)'
  task :grant, [:login] => :environment do |_task, args|
    user = AdminTasks.find_user!(args[:login])
    user.update!(admin: true)
    puts "#{user.username} <#{user.email}> is now an admin."
  end

  desc 'Remove admin rights: bin/rails "admin:revoke[someone@example.com]" (email or username)'
  task :revoke, [:login] => :environment do |_task, args|
    user = AdminTasks.find_user!(args[:login])
    user.update!(admin: false)
    puts "#{user.username} <#{user.email}> is no longer an admin."
  end

  desc 'List admins'
  task list: :environment do
    admins = User.where(admin: true).order(:id)
    puts admins.empty? ? 'No admins yet.' : admins.map { |u| "#{u.username} <#{u.email}>" }
  end
end

module AdminTasks
  # Admin is never set through a web form, so this task is how the first admin
  # (and any later ones) are made.
  def self.find_user!(login)
    abort 'Usage: bin/rails "admin:grant[email-or-username]"' if login.to_s.strip.empty?

    User.find_by(email: login.to_s.strip.downcase) || User.find_by(username: login.to_s.strip) ||
      abort("No user with email or username #{login.inspect}.")
  end
end
