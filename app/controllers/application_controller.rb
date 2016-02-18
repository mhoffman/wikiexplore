class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  def authenticate_user!(*args)
    current_user.present? || super(*args)
  end

  def current_user
    super || AnonymousUser.find_or_initialize_by(id: anonymous_user_token) do |user|
        user.save(validate: false) if user.new_record?
    end
  end

  private

  def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, key: [:username])
  end


  def anonymous_user_token
    session[:user_token] ||= SecureRandom.hex()
  end
end
