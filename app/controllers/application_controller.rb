class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session

  private

  def render_success(message = '')
    json = { type: 'success' }
    # unless message.empty?
    #   json[:data] = {
    #     message: message,
    #     code: WatchbotConstants::ErrorCodes::WARNING
    #   }
    # end
    render json: json, status: 200
  end

  def render_error(message, code, status = 400)
    render json: { type: 'error',
      data: {
        message: message,
        code: WatchbotConstants::ErrorCodes::const_get(code)
      }
    },
    status: status
  end

  def render_parameters_missing
    render_error 'Parameters missing', 'MISSING_PARAMETERS'
  end

  def render_not_found
    render_error 'Id not found', 'ID_NOT_FOUND', 404
  end
end
