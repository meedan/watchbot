class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  module ErrorCodes
    UNAUTHORIZED = 1
    MISSING_PARAMETERS = 2
    ID_NOT_FOUND = 3
    INVALID_VALUE = 4
    UNKNOWN = 5
    AUTH = 6
    WARNING = 7
    MISSING_OBJECT = 8
    DUPLICATED = 9
    ALL = %w(UNAUTHORIZED MISSING_PARAMETERS ID_NOT_FOUND INVALID_VALUE UNKNOWN AUTH WARNING MISSING_OBJECT DUPLICATED)
  end

  private

  def render_success(message = '')
    json = { type: 'success' }
    render json: json, status: 200
  end

  def render_error(message, code, status = 400)
    render json: { type: 'error',
      data: {
        message: message,
        code: ErrorCodes::const_get(code)
      }
    },
    status: status
  end

  def render_parameters_missing
    render_error 'Parameters missing', 'MISSING_PARAMETERS'
  end

  def render_not_found
    render_error 'URL not found', 'ID_NOT_FOUND', 404
  end
end
