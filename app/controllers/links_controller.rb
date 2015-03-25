class LinksController < ApplicationController
  respond_to :json

  before_filter :restrict_access

  def create
    begin
      render_parameters_missing and return if params[:url].blank?
      Link.create! url: params[:url]
      render_success
    rescue
      render_error 'Could not create link', 'UNKNOWN' 
    end
  end

  def destroy
    begin
      render_parameters_missing and return if params[:id].blank?
      @link = Link.where(url: params[:id]).first
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
      ApiKey.where(access_token: token, expire_at: { :$gte => Time.now }).exists?
    end
  end
end
