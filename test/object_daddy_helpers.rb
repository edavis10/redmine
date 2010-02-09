module ObjectDaddyHelpers
  # TODO: Remove these three once everyone has ported their code to use the
  # new object_daddy version with protected attribute support
  def User.generate_with_protected(attributes={})
    User.generate(attributes)
  end

  def User.generate_with_protected!(attributes={})
    User.generate!(attributes)
  end

  def User.spawn_with_protected(attributes={})
    User.spawn(attributes)
  end

  # Generate the default Query
  def Query.generate_default!(attributes={})
    query = Query.spawn(attributes)
    query.name ||= '_'
    query.save!
    query
  end

  # Generate an issue for a project, using it's trackers
  def Issue.generate_for_project!(project, attributes={})
    issue = Issue.spawn(attributes) do |issue|
      issue.project = project
    end
    issue.tracker = project.trackers.first unless project.trackers.empty?
    issue.save!
    issue
  end

end
