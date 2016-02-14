class AnonymousUser < User
  #ACCESSIBLE_ATTRS = [:name, :email]
  #attr_accessible *ACCESSIBLE_ATTRS, :type, :token, as: :registrant
  def register(params)
    params = params.merge(type: 'User', token: nil)
    self.update_attributes(params, as: :registrant)
  end
end
