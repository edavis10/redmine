module OpenIdAuthentication
  class Association < ActiveRecord::Base
    self.table_name = :open_id_authentication_associations

    def from_record
      OpenID::Association.new(handle, secret, issued, lifetime, assoc_type)
    end
  end
end
