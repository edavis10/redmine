xml.instruct!
xml.issues :type => 'array' do
  @issues.each do |issue|
	  xml.issue do
	    xml.id					issue.id
			xml.project(:id => issue.project_id, :name => issue.project.name) unless issue.project.nil?
			xml.tracker(:id => issue.tracker_id, :name => issue.tracker.name) unless issue.tracker.nil?
			xml.status(:id => issue.status_id, :name => issue.status.name) unless issue.status.nil?
			xml.priority(:id => issue.priority_id, :name => issue.priority.name) unless issue.priority.nil?
		 	xml.author(:id => issue.author_id, :name => issue.author.name) unless issue.author.nil?
		 	xml.assigned_to(:id => issue.assigned_to_id, :name => issue.assigned_to.name) unless issue.assigned_to.nil?
		  xml.category(:id => issue.category_id, :name => issue.category.name) unless issue.category.nil?
		  xml.fixed_version(:id => issue.fixed_version_id, :name => issue.fixed_version.name) unless issue.fixed_version.nil?
      xml.parent(:id => issue.parent_id) unless issue.parent.nil?
      
      xml.subject 		issue.subject
      xml.description issue.description
      xml.start_date 	issue.start_date
      xml.due_date 		issue.due_date
      xml.done_ratio 	issue.done_ratio
      xml.estimated_hours issue.estimated_hours
      
      xml.custom_fields do
      	issue.custom_field_values.each do |custom_value|
      		xml.custom_field custom_value.value, :id => custom_value.custom_field_id, :name => custom_value.custom_field.name
      	end
      end
      
      xml.created_on issue.created_on
      xml.updated_on issue.updated_on
    end
  end
end
