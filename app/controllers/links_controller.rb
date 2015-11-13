class LinksController < ApplicationController
  respond_to :json

  include LinksDoc

  before_filter :restrict_access

  def bulk_create
    success = failures = 0
    params.each do |param, url|
      unless (param =~ /^url/).nil?
        begin
          Link.create! url: url, application: @key.application
          success += 1
        rescue
          failures += 1
        end
      end
    end
    render_success "#{success} links created successfully and #{failures} links failed"
  end

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
