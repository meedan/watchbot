class LinksController < ApplicationController
  respond_to :json

  before_filter :restrict_access

  def create
    begin
      render_parameters_missing and return if params[:url].blank?
      Link.create! url: params[:url], application: @key.application
      render_success
    rescue
      render_error 'Could not create link', 'UNKNOWN' 
    end
  end

  def destroy
    begin
      render_parameters_missing and return if params[:url].blank?
      @link = Link.where(url: params[:url], application: @key.application).first
      if @link.nil?
        render_not_found
      else
        @link.destroy!
        render_success
      end
    rescue
      render_error 'Could not delete link', 'UNKNOWN' 
    end
  end

  private

  def restrict_access
    authenticate_or_request_with_http_token do |token, options|
      @key = ApiKey.where(access_token: token, expire_at: { :$gte => Time.now }).last
      !@key.nil?
    end
  end
end
