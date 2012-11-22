module ObjectHelpers
  def User.generate!(attributes={})
    @generated_user_login ||= 'user0'
    @generated_user_login.succ!
    user = User.new(attributes)
    user.login = @generated_user_login if user.login.blank?
    user.mail = "#{@generated_user_login}@example.com" if user.mail.blank?
    user.firstname = "Bob" if user.firstname.blank?
    user.lastname = "Doe" if user.lastname.blank?
    yield user if block_given?
    user.save!
    user
  end

  def User.add_to_project(user, project, roles=nil)
    roles = Role.find(1) if roles.nil?
    roles = [roles] unless roles.is_a?(Array)
    Member.create!(:principal => user, :project => project, :roles => roles)
  end

  def Group.generate!(attributes={})
    @generated_group_name ||= 'Group 0'
    @generated_group_name.succ!
    group = Group.new(attributes)
    group.name = @generated_group_name if group.name.blank?
    yield group if block_given?
    group.save!
    group
  end

  def Project.generate!(attributes={})
    @generated_project_identifier ||= 'project-0000'
    @generated_project_identifier.succ!
    project = Project.new(attributes)
    project.name = @generated_project_identifier if project.name.blank?
    project.identifier = @generated_project_identifier if project.identifier.blank?
    yield project if block_given?
    project.save!
    project
  end

  def Tracker.generate!(attributes={})
    @generated_tracker_name ||= 'Tracker 0'
    @generated_tracker_name.succ!
    tracker = Tracker.new(attributes)
    tracker.name = @generated_tracker_name if tracker.name.blank?
    yield tracker if block_given?
    tracker.save!
    tracker
  end

  def Role.generate!(attributes={})
    @generated_role_name ||= 'Role 0'
    @generated_role_name.succ!
    role = Role.new(attributes)
    role.name = @generated_role_name if role.name.blank?
    yield role if block_given?
    role.save!
    role
  end

  def Issue.generate!(attributes={})
    issue = Issue.new(attributes)
    issue.project ||= Project.find(1)
    issue.tracker ||= issue.project.trackers.first
    issue.subject = 'Generated' if issue.subject.blank?
    issue.author ||= User.find(2)
    yield issue if block_given?
    issue.save!
    issue
  end

  # Generate an issue for a project, using its trackers
  def Issue.generate_for_project!(project, attributes={})
    issue = Issue.new(attributes) do |issue|
      issue.project = project
      issue.tracker = project.trackers.first unless project.trackers.empty?
      issue.subject = 'Generated' if issue.subject.blank?
      issue.author ||= User.find(2)
      yield issue if block_given?
    end
    issue.save!
    issue
  end

  # Generates an issue with some children and a grandchild
  def Issue.generate_with_descendants!(project, attributes={})
    issue = Issue.generate_for_project!(project, attributes)
    child = Issue.generate_for_project!(project, :subject => 'Child1', :parent_issue_id => issue.id)
    Issue.generate_for_project!(project, :subject => 'Child2', :parent_issue_id => issue.id)
    Issue.generate_for_project!(project, :subject => 'Child11', :parent_issue_id => child.id)
    issue.reload
  end

  def Version.generate!(attributes={})
    @generated_version_name ||= 'Version 0'
    @generated_version_name.succ!
    version = Version.new(attributes)
    version.name = @generated_version_name if version.name.blank?
    yield version if block_given?
    version.save!
    version
  end

  def AuthSource.generate!(attributes={})
    @generated_auth_source_name ||= 'Auth 0'
    @generated_auth_source_name.succ!
    source = AuthSource.new(attributes)
    source.name = @generated_auth_source_name if source.name.blank?
    yield source if block_given?
    source.save!
    source
  end

  def Board.generate!(attributes={})
    @generated_board_name ||= 'Forum 0'
    @generated_board_name.succ!
    board = Board.new(attributes)
    board.name = @generated_board_name if board.name.blank?
    board.description = @generated_board_name if board.description.blank?
    yield board if block_given?
    board.save!
    board
  end
end
