xml.instruct!
xml.issue do
  xml.id					@issue.id
	xml.project(:id => @issue.project_id, :name => @issue.project.name) unless @issue.project.nil?
	xml.tracker(:id => @issue.tracker_id, :name => @issue.tracker.name) unless @issue.tracker.nil?
	xml.status(:id => @issue.status_id, :name => @issue.status.name) unless @issue.status.nil?
	xml.priority(:id => @issue.priority_id, :name => @issue.priority.name) unless @issue.priority.nil?
 	xml.author(:id => @issue.author_id, :name => @issue.author.name) unless @issue.author.nil?
 	xml.assigned_to(:id => @issue.assigned_to_id, :name => @issue.assigned_to.name) unless @issue.assigned_to.nil?
  xml.category(:id => @issue.category_id, :name => @issue.category.name) unless @issue.category.nil?
  xml.fixed_version(:id => @issue.fixed_version_id, :name => @issue.fixed_version.name) unless @issue.fixed_version.nil?
  
  xml.subject 		@issue.subject
  xml.description @issue.description
  xml.start_date 	@issue.start_date
  xml.due_date 		@issue.due_date
  xml.done_ratio 	@issue.done_ratio
  xml.estimated_hours @issue.estimated_hours
  if User.current.allowed_to?(:view_time_entries, @project)
  	xml.spent_hours		@issue.spent_hours
 	end
  
  xml.custom_fields do
  	@issue.custom_field_values.each do |custom_value|
  		xml.custom_field custom_value.value, :id => custom_value.custom_field_id, :name => custom_value.custom_field.name
  	end
  end unless @issue.custom_field_values.empty?
  
  xml.created_on @issue.created_on
  xml.updated_on @issue.updated_on
  
  xml.changesets do
  	@issue.changesets.each do |changeset|
  		xml.changeset :revision => changeset.revision do
  			xml.user(:id => changeset.user_id, :name => changeset.user.name) unless changeset.user.nil?
  			xml.comments changeset.comments
  			xml.committed_on changeset.committed_on
  		end
  	end
  end if User.current.allowed_to?(:view_changesets, @project) && @issue.changesets.any?
  
  xml.journals do
  	@issue.journals.each do |journal|
  		xml.journal :id => journal.id do
			 	xml.user(:id => journal.user_id, :name => journal.user.name) unless journal.user.nil?
  			xml.notes journal.notes
  			xml.details do
  				journal.details.each do |detail|
  					xml.detail :property => detail.property, :name => detail.prop_key, :old => detail.old_value, :new => detail.value
  				end
  			end
  		end
  	end
  end unless @issue.journals.empty?
end
