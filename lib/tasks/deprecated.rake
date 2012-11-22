def deprecated_task(name, new_name)
  task name=>new_name do
    $stderr.puts "\nNote: The rake task #{name} has been deprecated, please use the replacement version #{new_name}"
  end
end

deprecated_task :load_default_data, "redmine:load_default_data"
deprecated_task :migrate_from_mantis, "redmine:migrate_from_mantis"
deprecated_task :migrate_from_trac, "redmine:migrate_from_trac"
deprecated_task "db:migrate_plugins", "redmine:plugins:migrate"
deprecated_task "db:migrate:plugin", "redmine:plugins:migrate"
deprecated_task :generate_session_store, :generate_secret_token
